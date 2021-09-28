# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  describe "transistor episode v1" do
    before(:each) do
      stub_request(:get, %r{^https://api.transistor.fm/v1/analytics/episodes/\d+$}).
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            data: {
              id: "1",
              type: "episode_analytics",
              attributes: {},
            },
          }.to_json,
        )
      allow(Kernel).to receive(:sleep)
    end

    it_behaves_like "a service implementation", "transistor_episode_v1" do
      let(:body) do
        JSON.parse(<<~J)
          {
             "data":{
                "id":"655205",
                "type":"episode",
                "attributes":{
                   "title":"THE SHOW",
                   "number":1,
                   "season":1,
                   "status":"published",
                   "published_at":"2021-09-20T10:51:45.707-07:00",
                   "duration":236,
                   "explicit":false,
                   "keywords":"",
                   "alternate_url":"",
                   "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                   "image_url":null,
                   "author":"",
                   "summary":"readgssfdctwadg",
                   "description":"",
                   "created_at":"2021-09-20T10:06:08.582-07:00",
                   "updated_at":"2021-09-20T10:51:45.708-07:00",
                   "formatted_published_at":"September 20, 2021",
                   "duration_in_mmss":"03:56",
                   "share_url":"https://share.transistor.fm/s/70562b4e",
                   "formatted_summary":"readgssfdctwadg",
                   "audio_processing":false,
                   "type":"full",
                   "email_notifications":null
                },
                "relationships":{
                   "show":{
                      "data":{
                         "id":"24204",
                         "type":"show"
                      }
                   }
                }
             }
          }
        J
      end
      let(:expected_data) { body }
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "transistor_episode_v1" do
      let(:old_body) do
        JSON.parse(<<~J)
                    {
                       "data":{
                          "id":"655205",
                          "type":"episode",
                          "attributes":{
                             "title":"THE SHOW",
                             "number":1,
                             "season":1,
                             "status":"published",
                             "published_at":"2021-09-20T10:51:45.707-07:00",
                             "duration":236,
                             "explicit":false,
                             "keywords":"",
                             "alternate_url":"",
                             "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                             "image_url":null,
                             "author":"",
                             "summary":"readgssfdctwadg",
                             "description":"",
                             "created_at":"2021-09-20T10:06:08.582-07:00",
                             "updated_at":"2021-09-20T10:51:45.708-07:00",
                             "formatted_published_at":"September 20, 2021",
                             "duration_in_mmss":"03:56",
                             "share_url":"https://share.transistor.fm/s/70562b4e",
                             "formatted_summary":"readgssfdctwadg",
                             "audio_processing":false,
                             "type":"full",
                             "email_notifications":null
                          },
                          "relationships":{
                             "show":{
                                "data":{
                                   "id":"24204",
                                   "type":"show"
                                }
                             }
                          }
                       }
          }
        J
      end
      let(:new_body) do
        JSON.parse(<<~J)
          {
                    "data":{
                       "id":"655205",
                       "type":"episode",
                       "attributes":{
                          "title":"New title ",
                          "number":1,
                          "season":1,
                          "status":"published",
                          "published_at":"2021-09-20T10:51:45.707-07:00",
                          "duration":236,
                          "explicit":false,
                          "keywords":"",
                          "alternate_url":"",
                          "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                          "image_url":null,
                          "author":"",
                          "summary":"new summary",
                          "description":"",
                          "created_at":"2021-09-20T10:06:08.582-07:00",
                          "updated_at":"2021-09-22T10:51:45.708-07:00",
                          "formatted_published_at":"September 20, 2021",
                          "duration_in_mmss":"03:56",
                          "share_url":"https://share.transistor.fm/s/70562b4e",
                          "formatted_summary":"readgssfdctwadg",
                          "audio_processing":false,
                          "type":"full",
                          "email_notifications":null
                       },
                       "relationships":{
                          "show":{
                             "data":{
                                "id":"24204",
                                "type":"show"
                             }
                          }
                       }
                    }
          }
        J
      end
    end

    it_behaves_like "a service implementation that can backfill", "transistor_episode_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [{}, {}] }
      let(:page1_response) do
        <<~R
          {
            "data": [
              {
                "id": "1",
                "type": "episode",
                "attributes": {
                  "title": "How To Roast Coffee",
                  "summary": "A primer on roasting coffee",
                  "created_at":"2021-09-03T10:06:08.582-07:00"
                },
                "relationships": {}
              },
              {
                "id": "2",
                "type": "episode",
                "attributes": {
                  "title": "The Effects of Caffeine",
                  "summary": "A lightly scientific overview on how caffeine affects the brain",
                  "created_at":"2021-09-03T10:06:08.582-07:00"
                },
                "relationships": {}
              }
            ],
            "meta": {
              "currentPage": 1,
              "totalPages": 2,
              "totalCount": 4
            }
          }
        R
      end
      let(:page2_response) do
        <<~R
          {
            "data": [
              {
                "id": "3",
                "type": "episode",
                "attributes": {
                  "title": "I've actually decided I like tea better",
                  "summary": "A primer on good tea",
                  "created_at":"2021-09-03T10:06:08.582-07:00"
                },
                "relationships": {}
              },
              {
                "id": "4",
                "type": "episode",
                "attributes": {
                  "title": "The Effects of Quitting Caffeine",
                  "summary": "I think I should really cut down",
                  "created_at":"2021-09-03T10:06:08.582-07:00"
                },
                "relationships": {}
              }
            ],
            "meta": {
              "currentPage": 2,
              "totalPages": 2,
              "totalCount": 4
            }
          }
        R
      end
      let(:expected_backfill_call_count) { 2 }
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      before(:each) do
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
          with(
            body: "pagination%5Bpage%5D=1",
          ).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"})
        stub_request(:get, "https://api.transistor.fm/v1/episodes").
          with(
            body: "pagination%5Bpage%5D=2",
          ).
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"})
      end
    end

    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "returns a 202 no matter what" do
        req = fake_request
        status, _headers, _body = svc.webhook_response(req)
        expect(status).to eq(202)
      end
    end

    describe "state machine calculation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      describe "calculate_create_state_machine" do
        it "returns org database info" do
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! We've created your Transistor Episodes Service Integration.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "it asks for backfill key" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your API key here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/backfill_key")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("In order to backfill Transistor Episodoes, we need your API Key.")
        end
        it "returns backfill in progress message" do
          sint.backfill_key = "api_k3y"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your Transistor Episode information.",
          )
        end
      end
    end

    it_behaves_like "a service implementation that uses enrichments", "transistor_episode_v1" do
      let(:enrichment_tables) { [sint.table_name + "_stats"] }
      let(:body) do
        JSON.parse(<<~J)
          {"data": {
                "id":"655205",
                "type":"episode",
                "attributes":{
                   "title":"THE SHOW",
                   "number":1,
                   "season":1,
                   "status":"published",
                   "published_at":"2021-09-20T10:51:45.707-07:00",
                   "duration":236,
                   "explicit":false,
                   "keywords":"",
                   "alternate_url":"",
                   "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                   "image_url":null,
                   "author":"",
                   "summary":"readgssfdctwadg",
                   "description":"",
                   "created_at":"2021-09-03T10:06:08.582-07:00",
                   "updated_at":"2021-09-20T10:51:45.708-07:00",
                   "formatted_published_at":"September 20, 2021",
                   "duration_in_mmss":"03:56",
                   "share_url":"https://share.transistor.fm/s/70562b4e",
                   "formatted_summary":"readgssfdctwadg",
                   "audio_processing":false,
                   "type":"full",
                   "email_notifications":null
                },
                "relationships":{
                   "show":{
                      "data":{
                         "id":"24204",
                         "type":"show"
                      }
                   }
                }
          }}
        J
      end
      let(:analytics_body) do
        <<~R
          {
             "data":{
                "id":"655205",
                "type":"episode_analytics",
                "attributes":{
                   "downloads":[
                      {
                         "date":"03-09-2021",
                         "downloads":0
                      },
                      {
                         "date":"04-09-2021",
                         "downloads":0
                      }
                   ],
                   "start_date":"03-09-2021",
                   "end_date":"16-09-2021"
                },
                "relationships":{
                   "episode":{
                      "data":{
                         "id":"1",
                         "type":"episode"
                      }
                   }
                }
             },
             "included":[
                {
                   "id":"655205",
                   "type":"episode",
                   "attributes":{
                      "title":"THE SHOW"
                   },
                   "relationships":{
                   }
                }
             ]
          }
        R
      end

      before(:each) do
        stub_request(:get, "https://api.transistor.fm/v1/analytics/episodes/655205").
          to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: analytics_body,
          )
      end

      def assert_is_enriched(_row)
        # we are not enriching data within the table, so this can just return true
        return true
      end

      def assert_enrichment_after_insert(db)
        enrichment_table_sym = enrichment_tables[0].to_sym
        expect(db[enrichment_table_sym].all).to have_length(2)

        entry = db[enrichment_table_sym].first
        expect(entry).to include(episode_id: "655205", downloads: 0)
      end
    end

    describe "_fetch_enrichment" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "transistor_episode_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }
      let(:body) do
        JSON.parse(<<~J)
          {"data": {
                "id":"655205",
                "type":"episode",
                "attributes":{
                   "title":"THE SHOW",
                   "number":1,
                   "season":1,
                   "status":"published",
                   "published_at":"2021-09-20T10:51:45.707-07:00",
                   "duration":236,
                   "explicit":false,
                   "keywords":"",
                   "alternate_url":"",
                   "media_url":"https://media.transistor.fm/70562b4e/83984906.mp3",
                   "image_url":null,
                   "author":"",
                   "summary":"readgssfdctwadg",
                   "description":"",
                   "created_at":"2021-09-03T10:06:08.582-07:00",
                   "updated_at":"2021-09-20T10:51:45.708-07:00",
                   "formatted_published_at":"September 20, 2021",
                   "duration_in_mmss":"03:56",
                   "share_url":"https://share.transistor.fm/s/70562b4e",
                   "formatted_summary":"readgssfdctwadg",
                   "audio_processing":false,
                   "type":"full",
                   "email_notifications":null
                },
                "relationships":{
                   "show":{
                      "data":{
                         "id":"24204",
                         "type":"show"
                      }
                   }
                }
          }}
        J
      end

      it "sleeps to avoid rate limiting" do
        Webhookdb::Transistor.sleep_seconds = 1.2
        expect(Kernel).to receive(:sleep).with(1.2)
        svc._fetch_enrichment(body)
      end
    end
  end
end