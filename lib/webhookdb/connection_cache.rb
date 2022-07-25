# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"

require "webhookdb"

# Keep a dynamic cache of open database connections.
# Very similar in behavior to Sequel::DATABASES,
# but we need to prune connections that have not been inactive for a while.
#
# When `borrow` is called, either a new connection is made,
# or an existing one used, for that URL. The connection is yield to the block.
#
# Then, after the block is called,
# if 'prune_interval' has elapsed since the last prune,
# prune all connections with 0 current connections,
# _other than the connection just used_.
# Because this connection was just used,
# we assume it will be used again soon.
#
# The idea here is that:
# - We cannot connect to the DB statically; each org can have its own DB,
#   so storing it statically would increase DB connections to the the number of orgs in the database.
# - So we replace the organization/synchronization done in Sequel::DATABASES with ConnectionCache.
# - Any number of worker threads need access to the same DB; rather than connecting inline,
#   which is very slow, all DB connections for an org (or across orgs if not in database isolation)
#   can share connections via ConnectionCache.
# - In single-org/db environments, the active organization will always always be the same,
#   so the connection is never returned.
# - In multi-org/db environments, busy orgs will likely stay busy. But a reconnect isn't the end
#   of the world.
# - It seems more efficient to be pessimistic about future use, and prune anything with 0 connections,
#   rather than optimistic, and use an LRU or something similar, since the connections are somewhat
#   expensive resources to keep open for now reason. That said, we could switch this out for an LRU
#   it the pessimistic pruning results in many reconnections. It would also be reasonable to increase
#   the prune interval to avoid disconnecting as frequently.
class Webhookdb::ConnectionCache
  include Appydays::Configurable
  include Appydays::Loggable
  extend Webhookdb::MethodUtilities
  include Webhookdb::Dbutil

  configurable(:connection_cache) do
    # If this many seconds has elapsed since the last connecton was borrowed,
    # prune connections with no pending borrows.
    setting :prune_interval, 120

    # Seconds for the :fast timeout option.
    setting :timeout_fast, 30
    # Seconds for the :slow_schema timeout option.
    setting :timeout_slow_schema, 30.minutes.to_i
  end

  singleton_attr_accessor :_instance

  def self.borrow(url, **kw, &)
    return self._instance.borrow(url, **kw, &)
  end

  def self.disconnect(url)
    self._instance.disconnect(url)
  end

  def self.force_disconnect_all
    self._instance.force_disconnect_all
  end

  attr_accessor :databases, :prune_interval, :last_pruned_at

  def initialize(prune_interval:)
    @databases = {}
    @prune_interval = prune_interval
    @last_pruned_at = Time.now
  end

  # Connect to the database at the given URL
  # (or reuse existing connection),
  # and yield the database to the given block.
  # See class docs for more details.
  def borrow(url, opts={}, &block)
    raise LocalJumpError if block.nil?
    raise ArgumentError, "url cannot be blank" if url.blank?
    now = Time.now
    url_cache = @databases[url]
    if url_cache.nil?
      db = take_conn(url, extensions: [:pg_json])
      url_cache = {pending: 1, connection: db}
      @databases[url] = url_cache
    else
      url_cache[:pending] += 1
    end
    timeout = opts[:timeout]
    if timeout.is_a?(Symbol)
      timeout_name = "timeout_#{timeout}"
      begin
        timeout = Webhookdb::ConnectionCache.send(timeout_name)
      rescue NoMethodError
        raise NoMethodError, "no timeout accessor :#{timeout_name}"
      end
    end
    conn = url_cache[:connection]
    conn << "SET statement_timeout TO #{timeout * 1000}" if timeout.present?
    begin
      result = yield conn
    rescue Sequel::DatabaseError
      conn << "ROLLBACK;"
      raise
    ensure
      conn << "SET statement_timeout TO 0" if timeout.present?
      url_cache[:pending] -= 1
    end
    self.prune(url) if now > self.next_prune_at
    return result
  end

  def next_prune_at = self.last_pruned_at + self.prune_interval

  # Disconnect the cached connection for the given url,
  # if any. In general, this is only needed when tearing down a database.
  def disconnect(url)
    raise ArgumentError, "url cannot be blank" if url.blank?
    url_cache = @databases[url]
    return if url_cache.nil?
    if url_cache[:pending].positive?
      raise Webhookdb::InvalidPrecondition,
            "url #{displaysafe_url(url)} still has #{url_cache[:pending]} active connections"

    end
    db = url_cache[:connection]
    db.disconnect
    @databases.delete(url)
  end

  protected def prune(skip_url)
    @databases.delete_if do |url, url_cache|
      next false if url_cache[:pending].positive?
      next if url == skip_url
      if url_cache[:pending].negative?
        raise "invariant violation: url_cache pending is negative: " \
              "#{displaysafe_url(url)}, #{url_cache.inspect}"
      end
      url_cache[:connection].disconnect
      true
    end
    self.last_pruned_at = Time.now
  end

  def force_disconnect_all
    self.databases.each_value do |url_cache|
      url_cache[:connection].disconnect
    end
    @databases.clear
  end
end

Webhookdb::ConnectionCache._instance = Webhookdb::ConnectionCache.new(
  prune_interval: Webhookdb::ConnectionCache.prune_interval,
)
