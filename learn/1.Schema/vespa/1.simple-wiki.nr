#%%python
#H1 imports
# in the conda env: pip install pyvespa beautifulsoup4 requests
from vespa.package import ApplicationPackage, Field, Schema, Document
from vespa.deployment import VespaDocker
from vespa.application import Vespa
from bs4 import BeautifulSoup
import requests
from urllib.parse import urlparse
#%%python
#H1 schema
wiki_schema = Schema(
    name="wiki",
    document=Document(
        fields=[
            Field(
                name="link",
                type="string",
                indexing=["summary", "attribute"]
            ),
            Field(
                name="body",
                type="string",
                indexing=["summary", "index"],
            ),
        ],
    ),
)
#%%python
#H1 deploy
# bundle the schema into an application package and deploy it to a new container
app_package = ApplicationPackage(name="simplewiki", schema=[wiki_schema])
vespa_docker = VespaDocker(port=8080, cfgsrv_port=19071)
# this will take up to a minute
app = vespa_docker.deploy(application_package=app_package)
print(f"✅ Deployed 'wiki' schema to Vespa at: {app.url}:{app.port}")
#%%python
#H1 download and parse a sample document
url = "https://en.wikipedia.org/wiki/Artificial_intelligence_visual_art"
# download HTML
response = requests.get(url, timeout=30)
response.raise_for_status()
html = response.text
# extract readable text
soup = BeautifulSoup(html, "html.parser")
paragraphs = [p.get_text(separator=" ", strip=True) for p in soup.find_all("p")]
body_text = "\n\n".join([p for p in paragraphs if p])
if not body_text:
    body_text = soup.get_text(separator=" ", strip=True)
#%%python
#H1 Feed the document to Vespa
# construct an id from the URL path
path = urlparse(url).path.strip("/")
doc_id = path.replace("/", "_") or "index"
# feed document with pyvespa
fields = {"link": url, "body": body_text}
feed_response = app.feed_data_point(
    schema="wiki",
    data_id=doc_id,
    fields=fields,
)
print("✅ Feed ok:", feed_response.is_successful(), "status:", getattr(feed_response, "status_code", None))
#%%vespa
#H1 query
POST http://localhost:8080/search/
{
  "yql": "select * from wiki where body contains 'visual'",
  "hits": 3
}