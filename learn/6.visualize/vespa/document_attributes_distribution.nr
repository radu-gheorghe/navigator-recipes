#%%python
#H1 Visualizing price, images and rating breakdown
# imports
import polars as pl
from vespa.application import Vespa
print("Imports done")
#%%python
#H2 Initializing pyvespa to our application
vespa_app = Vespa(url="https://f02beae1.dd11e0c7.z.vespa-app.cloud", cert='/Users/radu/.vespa/training1.ranking.default/data-plane-public-cert.pem',
  key='/Users/radu/.vespa/training1.ranking.default/data-plane-private-key.pem')
print("App object initialized")
#%%python
#H2 Quantiles with pyvespa
with vespa_app.syncio(connections=1) as session:
    response = session.query(yql='''
    select * from product where true limit 0 | 
      all( group('all') each(
        output(quantiles([0.1,0.3,0.5,0.7,0.9],Price))
        output(quantiles([0.1,0.3,0.5,0.7,0.9],AverageRating))
    ))
    ''')
print(json.dumps(response.get_json(), indent=2))
#%%vespa
#H3 We could do REST requests and put results in a variable
%AssignRequestResponse_toPythonDict:vespaResponse
POST https://f02beae1.dd11e0c7.z.vespa-app.cloud/search/
{
  "select": {
    "where": true,
    "grouping": [
      {
        "all": {
          "group": "\"all\"",
          "each": {
            "output": [
              "quantiles([0.1,0.3,0.5,0.7,0.9],Price)",
              "quantiles([0.1,0.3,0.5,0.7,0.9],AverageRating)"
            ]
          }
        }
      }
    ]
  },
  "hits": 0
}
# but we'll need to do stuff in Python later, hence the Vespa app
#%%python
#H3 Raw results
grouping_result = response.get_json()['root']['children'][0]['children'][0]['children'][0]['fields']
print(json.dumps(grouping_result, indent=2))
#%%python
#H3 Pricing graph
price_data = grouping_result["quantiles([0.1,0.3,0.5,0.7,0.9],Price)"]
df = pl.DataFrame(price_data)
print(df)
navigator_display_dataFrame(DataFrame=df)

# make sure to set quantile as X axis, like so:
#navigator_display_chart(DataFrame=df, chartType='lineChart', xAxis='quantile', yAxis=["value"])
#%%python
#H3 All in the same graph
# Note: this doesn't mean they're correlated! Different products have different values
price_df = pl.DataFrame(grouping_result["quantiles([0.1,0.3,0.5,0.7,0.9],Price)"]).rename({"value": "Price"})
rating_df = pl.DataFrame(grouping_result["quantiles([0.1,0.3,0.5,0.7,0.9],AverageRating)"]).rename({"value": "AverageRating"})

all_quantiles_df = price_df.join(rating_df, on="quantile")

print(all_quantiles_df)
# uncomment to start the chart from scratch
#navigator_display_dataFrame(DataFrame=all_quantiles_df)

# ready-made line chart with quantiles as X axis
navigator_display_chart(DataFrame=all_quantiles_df, chartType='lineChart', xAxis='quantile', yAxis=["Price","AverageRating"], multiYAxis=True)
#%%python
#H1 Visualizing judgements
df = pl.read_csv(
    "/Users/radu/gits/university/ranking/ch2/evaluation/judgements.csv",
    dtypes={
        "query_id": pl.Int16,
        "document_id": pl.String,
        "rating": pl.Int8,
    },
)
print("Read judgements CSV")
#%%python
#H2 Judgement quantiles per query
quantiles = [0.1, 0.3, 0.5, 0.7, 0.9]

agg_exprs = [
    pl.col("rating").quantile(p, interpolation="nearest").alias(str(p))
    for p in quantiles
]

# compute per-query quantiles
judgements_df = df.group_by("query_id").agg(agg_exprs)
print(judgements_df)
#%%python
#H3 Visualizing first 10
navigator_display_dataFrame(DataFrame=judgements_df[:10])
#%%python
#H3 Median of all (sampled)
navigator_display_chart(DataFrame=judgements_df, chartType='lineChart', xAxis='query_id', yAxis=["0.5"], yAxisColors=[3], sampling=True)
#%%python
#H1 Visualizing query scores
# TODO we can also connect queries/results with judgements. For another time
df = pl.read_csv(
    "/Users/radu/gits/university/ranking/ch2/evaluation/queries.csv",
    dtypes={
        "query_id": pl.Int16,
        "query_text": pl.String
    },
)
print("Read queries CSV")
#%%python
#H2 Sample query
query_body = {
  "yql": '''
    select * from product where ({targetHits:100}nearestNeighbor(ProductName_embedding,q_embedding)) OR ({targetHits:100}nearestNeighbor(Description_embedding,q_embedding)) OR
      userQuery()
    ''',
  "query": "home decor items",
  "input.query(q_embedding)": "embed(@query)",
  "ranking.profile": "debug"
}

with vespa_app.syncio(connections=1) as session:
    response = session.query(body=query_body)
print(json.dumps(response.get_json(), indent=2))
#%%python
#H2 Run all queries
queries = []
for query in df['query_text'].to_list():
  query_body['query'] = query
  queries.append(query_body)

responses = await vespa_app.query_many_async(queries=queries)

print(f"Ran {df.height} queries")
#%%python
#H2 Take a few responses
# take one query
all_responses = [response.json for response in responses]

sample_responses = all_responses[:20]

print(json.dumps(sample_responses, indent=2))
#%%python
#H2 Build the Polars dataframe
FEATURES = [
    "closeness_description",
    "closeness_productname",
    "native_rank_description",
    "native_rank_name",
]

rows = []
i = 0
for resp in sample_responses:
    qtext = queries[i]["query"]
    for hit in resp["root"].get("children", []):  # all returned docs for this query
        fields = hit.get("fields", {})
        sf = fields.get("summaryfeatures", {}) or {}
        rows.append({
            "query_index": i,
            "query": qtext,
            "document_id": fields.get("documentid"),
            # (optional) keep some extra identifiers:
            "product_id": fields.get("ProductID"),
            "product_name": fields.get("ProductName"),
            # summary features -> columns
            **{k: sf.get(k) for k in FEATURES},
        })
    i += 1

queries_docs_df = pl.DataFrame(rows)
print(queries_docs_df)
#%%python
#H2 Notice how semantic completely dominates the score
# feel free to zoom in to see the actual values
navigator_display_chart(DataFrame=queries_docs_df, chartType='scatterPlotChart', xAxis='document_id', yAxis=["closeness_description","closeness_productname","native_rank_description","native_rank_name"], sampling=True)

# navigator_display_dataFrame(DataFrame=queries_docs_df)