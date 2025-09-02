#%%python
#H1 imports
# in the conda env: pip install pyvespa polars
from vespa.package import ApplicationPackage, Field, Schema, Document
from vespa.deployment import VespaDocker
from vespa.application import Vespa
from vespa.io import VespaResponse
import polars as pl
import json
#%%python
#H1 read TSV file
# TODO we should use relative paths here
df = pl.read_csv(
    "/Users/radu/gits/navigator-recipes/Resources/wiki_metadata.tsv",
    separator="\t",
    has_header=True,
    infer_schema_length=5000,     # number of rows to use for infering data types
    null_values=[""],  # common null tokens
    try_parse_dates=True,
)
#%%python
#H1 Polars detected data types
polars_schema = {}
for name, dtype in df.schema.items():
  polars_schema[name] = str(dtype)
print(json.dumps(polars_schema, indent=2))
#%%python
#H1 Map them to Vespa data types 
# non-exhaustive list. Check https://docs.pola.rs/api/python/stable/reference/datatypes.html and https://docs.vespa.ai/en/reference/schema-reference.html for details
polars_to_vespa = {
  "Float32": "float",
  "Float64": "double",
  "Int8": "byte",
  "Int16": "int",
  "Int32": "int",
  "Int64": "long",
  "Uint8": "int",
  "Uint16": "int",
  "Uint32": "long",
  "String": "string"
}
vespa_schema_dict = {}
for field in polars_schema:
  vespa_schema_dict[field] = polars_to_vespa[polars_schema[field]]
print(json.dumps(vespa_schema_dict, indent=2))
#%%python
#H1 Create a Vespa Schema 
vespa_fields = []
for field in vespa_schema_dict:
  vespa_fields.append(Field(
                name=field,
                type=vespa_schema_dict[field],
                indexing=["summary", "attribute"]
            ))
  # index strings as well
  if vespa_schema_dict[field] == "string":
    vespa_fields.append(Field(
                name=field + "_t",
                type=vespa_schema_dict[field],
                indexing=["input " + field, "index"],
                is_document_field=False
            ))

wiki_schema = Schema(
    name="wiki",
    document=Document(
        fields=vespa_fields
    )
)
#%%python
#H1 Deploy
# bundle the schema into an application package and deploy it to a new container
app_package = ApplicationPackage(name="metadatawiki", schema=[wiki_schema])
vespa_docker = VespaDocker(port=8080, cfgsrv_port=19071)
# this will take up to a minute
app = vespa_docker.deploy(application_package=app_package)
print(f"✅ Deployed 'wiki' schema to Vespa at: {app.url}:{app.port}")
#%%python
#H1 Feed the test data
# do we have an id field? If not, let's add
ID_FIELD = "id"
if ID_FIELD not in df.columns:
  df = df.with_row_index(name=ID_FIELD)

# convert rows to feed format
def tsv_rows_to_vespa(df: pl.DataFrame):
    for row in df.iter_rows(named=True):
        fields = {k: v for k, v in row.items()}
        doc_id = fields.pop(ID_FIELD)
        yield {"id": doc_id, "fields": fields}

# callback function to bubble up failures
def callback(r: VespaResponse, doc_id: str):
    if not r.is_successful():
        print(f"[feed error] id={doc_id} status={r.status_code} payload={r.get_json()}")

# feed using HTTP/2
from threading import Thread

def run_feeder():
  app.feed_async_iterable(
      iter=tsv_rows_to_vespa(df),
      schema="wiki",
      namespace="default",
      callback=callback
  )

# We need to run this in a separate thread, so we can use asyncio
# inside this recipe env.
# On standalone Python you can run feed_async_iterable directly
t = Thread(target=run_feeder, daemon=False)
t.start()
t.join()
#%%vespa
#H1 Test query 
POST http://localhost:8080/search/
{
  "yql": "select * from wiki where true",
  "hits": 3
}