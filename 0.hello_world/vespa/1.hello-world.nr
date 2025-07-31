#%%python
#H1 imports
# in the conda env: pip install pyvespa
from vespa.package import ApplicationPackage, Field, Schema, Document
from vespa.deployment import VespaDocker
from vespa.application import Vespa
#%%python
#H1 schema
# define the 'product' schema with just the three fields
product_schema = Schema(
    name="product",
    document=Document(
        fields=[
            Field(
              # for full-text search
                name="title",
                type="string",
                indexing=["summary", "index"]
            ),
            Field(
              # for faceting
                name="category",
                type="string",
                indexing=["summary", "attribute"],
            ),
            Field(
                name="price",
                type="float",
                indexing=["summary", "attribute"],
            ),
        ],
    ),
)
#%%python
#H1 deploy
# bundle the schema into an application package and deploy it to a new container
app_package = ApplicationPackage(name="lexicalsearch", schema=[product_schema])
vespa_docker = VespaDocker(port=8080, cfgsrv_port=19071)
# this will take up to a minute
app = vespa_docker.deploy(application_package=app_package)
print(f"✅ Deployed 'product' schema to Vespa at: {app.url}:{app.port}")
#%%vespa
#H1 add docs
POST http://localhost:8080/document/v1/productspace/product/docid/first
{
  "fields": {
    "title": "first product",
    "category": "freeware",
    "price": 0
  }
}
#%%vespa
POST http://localhost:8080/document/v1/productspace/product/docid/2
{
  "fields": {
    "title": "second product",
    "category": "expensive",
    "price": 1000
  }
}
#%%vespa
#H1 query
# look for "first" in the title
POST http://localhost:8080/search/
{
  "yql": "select * from product where title contains 'first'"
}