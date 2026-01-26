#%%markdown
![Visual of what we're doing](TODO)
#%%bash
#H1 Point Vespa CLI to Vespa Cloud
vespa config set target cloud
#%%markdown
#H2 Point it to your application
Format: tenant.application-name

**Tenant** is your billing unit. When you create your Vespa Cloud account, you create a tenant.
Though you can have access to multiple tenants (e.g., your personal one and your organisation's).

**Application name** identifies your Vespa deployment.
There are separate VMs storing data, separate endpoints, etc. for each application.
#%%bash
#H3 Vespa CLI command to point to the target application
vespa config set application training1.test-wiki
#%%bash
#H2 Authenticate it to your account
vespa auth login
#%%bash
#H2 Get current config to make sure it's OK
vespa config get
#%%markdown
#H1 Deploy the app
**NOTE**: First step depends on your operating system.
#%%bash
#H2 [Linux, Mac] Change to the application package directory
cd launch/vespa/wiki_app
pwd
#%%bash
#H2 [Windows] Change to the application package directory
cd launch\vespa\wiki_app
dir
#%%bash
#H2 Generate mTLS certificates
vespa auth cert -f
#%%bash
#H2 Write down the certificate and private key paths
Check the first two lines of the output of the last cell (no need to re-run it, it's cached).

You can use this cell to write them down. We'll need them to connect to Vespa after we deploy.
#%%markdown
#H2 Deploy
Takes a few minutes to launch and prepare the VMs.

Subsequent deploys (e.g., on a schema change) take **much less** time.
#%%bash
#H3 Vespa CLI command to deploy
vespa deploy --wait 900
#%%markdown
#H1 Connect Navigator to your Vespa application
Use the endpoint selector on top to create a new Vespa Cloud connection.

Fill in the certificate paths from step 2.4 and the endpoint name from the deployment output (previous cell).

For automatic field completion, fill in the following schema paths as well.

Finally, click on the defined endpoint to connect.
#%%bash
#H2 [Linux, Mac] Schema path
ls `pwd`/schemas/fragment.sd
#%%bash
#H2 [Windows] Schema path
dir "%cd%\schemas\fragment.sd"
#%%bash
#H1 Feed sample data
# TODO make sure the data is there
vespa feed --progress 3 ~/Documents/navigator/Wikipedia-Fragments-v6.ndjson
#%%vespa
#H1 Run a Select All query
POST /search/
{
  "yql": "select * from sources * where true",
}
#%%bash
#H1 Clean up
vespa destroy