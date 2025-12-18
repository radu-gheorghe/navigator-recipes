#%%markdown
# TODO: concepts/steps visual?
#%%bash
#H1 Point Vespa CLI to Vespa Cloud
vespa config set target cloud
#%%bash
#H2 Point it to your application
vespa config set application training1.test-wiki
#%%bash
#H2 Authenticate it to your account
vespa auth login
#%%bash
#H2 Get current config
vespa config get
#%%bash
#H1 Deploy the app
# application package should be here
cd gits/navigator-recipes/launch/vespa/wiki_app
pwd
#%%bash
#H2 Generate mTLS certs
vespa auth cert -f
#%%bash
#H2 Deploy
vespa deploy
#%%bash
#H1 Feed sample data
# TODO: feed with pyvespa? crawl data in this recipe?
vespa feed ~/Documents/navigator/Wikipedia-Fragments-v6.ndjson
#%%vespa
#H1 Run a Select All query
# TODO: set up the Vespa Cloud endpoint
POST /search/
{
  "yql": "select article_title_s,content_t from fragment where true"
}
#%%bash
#H1 Clean up
vespa destroy