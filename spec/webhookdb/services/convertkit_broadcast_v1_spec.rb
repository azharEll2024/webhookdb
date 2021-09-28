# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  describe "convertkit broadcast v1" do
    before(:each) do
      stub_request(:get, %r{^https://api.convertkit.com/v3/broadcasts/\d+/stats}).
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            broadcast: [
              {
                id: 10_000_000,
                stats:
                  {},
              },
            ],
          }.to_json,
        )
      allow(Kernel).to receive(:sleep)
    end

    it_behaves_like "a service implementation", "convertkit_broadcast_v1" do
      let(:body) do
        JSON.parse(<<~J)
          {
            "id":2641288,
            "name":"Example Broadcast",
            "created_at":"2021-09-22T20:40:49.000Z"
          }
        J
      end
      let(:expected_data) { body }
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "convertkit_broadcast_v1" do
      let(:old_body) do
        JSON.parse(<<~J)
          {
            "id":2641288,
            "name":"Example Broadcast",
            "created_at":"2021-09-21T20:40:49.000Z"
          }
        J
      end
      let(:new_body) do
        JSON.parse(<<~J)
          {
            "id":2641288,
            "name":"Example Broadcast",
            "created_at":"2021-09-22T20:40:49.000Z"
          }
        J
      end
    end

    it_behaves_like "a service implementation that can backfill", "convertkit_broadcast_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [] }
      let(:page1_response) do
        <<~R
                    {
            "broadcasts": [
              {
                "id": 1,
                "created_at": "2014-02-13T21:45:16.000Z",
                "subject": "Welcome to my Newsletter!"
              },
              {
                "id": 2,
                "created_at": "2014-02-20T11:40:11.000Z",
                "subject": "Check out my latest blog posts!"
              }
            ]
          }
        R
      end
      let(:page2_response) do
        <<~R
          {}
        R
      end
      let(:expected_backfill_call_count) { 1 }
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      before(:each) do
        stub_request(:get, "https://api.convertkit.com/v3/broadcasts?api_secret=bfsek").
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"})
      end
    end

    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "returns a 202 no matter what" do
        req = fake_request
        status, _headers, _body = svc.webhook_response(req)
        expect(status).to eq(202)
      end
    end

    describe "state machine calculation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      describe "calculate_create_state_machine" do
        it "returns org database info" do
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! We've created your ConvertKit Broadcast Service Integration.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "it asks for backfill secret" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your API secret here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/" \
                                                    "transition/backfill_secret")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("In order to backfill ConvertKit Broadcasts, we need your API secret.")
        end
        it "returns backfill in progress message" do
          sint.backfill_secret = "api_s3cr3t"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your ConvertKit Broadcast information.",
          )
        end
      end
    end

    it_behaves_like "a service implementation that uses enrichments", "convertkit_broadcast_v1" do
      let(:enrichment_tables) { [] }
      let(:body) do
        JSON.parse(<<~J)
          {
            "id": 1,
            "subject":"The Broadcast",
            "created_at":"2021-09-21T20:40:49.000Z"
          }
        J
      end
      let(:analytics_body) do
        <<~R

          {
            "broadcast": [
              {
                "id":1,
                "stats":
                {
                  "recipients": 82,
                  "open_rate": 60.975,
                  "click_rate": 23.17,
                  "unsubscribes": 9,
                  "total_clicks": 15,
                  "show_total_clicks": false,
                  "status": "completed",
                  "progress": 100.0
                }
              }
            ]
          }
        R
      end

      before(:each) do
        stub_request(:get, "https://api.convertkit.com/v3/broadcasts/1/stats?api_secret=").
          to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: analytics_body,
          )
      end

      def assert_is_enriched(row)
        expect(row[:recipients]).to eq(82)
        expect(row[:open_rate]).to eq(60.975)
        expect(row[:click_rate]).to eq(23.17)
        expect(row[:unsubscribes]).to eq(9)
        expect(row[:total_clicks]).to eq(15)
        expect(row[:show_total_clicks]).to eq(false)
        expect(row[:status]).to eq("completed")
        expect(row[:progress]).to eq(100.0)
      end

      def assert_enrichment_after_insert(_db)
        # we are not putting enriched data in a separate table, so this can just return true
        return true
      end
    end

    describe "_fetch_enrichment" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "convertkit_broadcast_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }
      let(:body) do
        JSON.parse(<<~J)
          {
            "id":1,
            "name":"The Broadcast",
            "created_at":"2021-09-22T20:40:49.000Z"
          }
        J
      end

      it "sleeps to avoid rate limiting" do
        Webhookdb::Convertkit.sleep_seconds = 1.2
        expect(Kernel).to receive(:sleep).with(1.2)
        svc._fetch_enrichment(body)
      end
    end
  end
end