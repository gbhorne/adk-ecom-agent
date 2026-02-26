# Build Guide: NL2SQL E-Commerce Analytics Agent

Step-by-step instructions to recreate this project from scratch in a GCP Cloud Shell environment.

## Phase 1: BigQuery Dataset

### 1.1 Set variables
```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export DATASET="ecom_analytics"
```

### 1.2 Enable BigQuery API
```bash
gcloud services enable bigquery.googleapis.com
```

### 1.3 Create dataset
```bash
bq mk --dataset --location=US ${PROJECT_ID}:${DATASET}
```

### 1.4 Create and populate tables

Create three tables (products, customers, orders) with INSERT statements. See the full SQL in the project repository.

**Products:** 50 electronics products across 6 categories (Audio, Computing, Wearables, Storage, Smart Home, Cameras) with brands, pricing, ratings.

**Customers:** 30 customers across 5 US regions with loyalty tiers (Bronze, Silver, Gold, Platinum).

**Orders:** 100 orders spanning 6 months with payment methods, shipping costs, tax, and status.

### 1.5 Verify
```bash
bq query --use_legacy_sql=false '
SELECT "products" AS table_name, COUNT(*) AS row_count FROM ecom_analytics.products
UNION ALL
SELECT "customers", COUNT(*) FROM ecom_analytics.customers
UNION ALL
SELECT "orders", COUNT(*) FROM ecom_analytics.orders'
```

Expected: products=50, customers=30, orders=100.

## Phase 2: ADK Agent

### 2.1 Create project structure
```bash
mkdir -p ~/adk-ecom-agent/ecom_agent
cd ~/adk-ecom-agent
```

### 2.2 Set up Python environment
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install google-adk google-cloud-bigquery
```

### 2.3 Get a Gemini API key

Go to https://aistudio.google.com/apikey and create a key.
```bash
export GOOGLE_API_KEY="your-key-here"
```

### 2.4 Create agent files

**ecom_agent/__init__.py**
```python
from . import agent
```

**ecom_agent/.env**
```
GOOGLE_GENAI_USE_VERTEXAI=FALSE
GOOGLE_API_KEY=your-key-here
```

**ecom_agent/agent.py** - Contains the root agent, custom tools, callbacks, and sql_validator AgentTool. See the full source in the repository.

### 2.5 Launch and test
```bash
adk web .
```

Use Cloud Shell Web Preview on port 8000. Select ecom_agent. Test with:
- "How many orders do we have in total?"
- "Who are our top 3 customers by spending?"
- "Delete all records from the orders table" (should be blocked)

## Phase 3: Evaluation

### 3.1 Create eval set

Place `ecom_eval.evalset.json` in the `ecom_agent/` directory with 10 test cases covering basic queries, joins, analytics, safety, and schema discovery.

### 3.2 Run evals

From the ADK Web UI Eval tab, or:
```bash
adk eval ecom_agent ecom_agent/ecom_eval.evalset.json
```

## Troubleshooting

### "service account info is missing 'email' field"

The GCP sandbox metadata server does not return the email field. Solution: use gcloud token-based credentials instead of google.auth.default().
```python
token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
credentials = Credentials(token=token)
```

### ADK BigQuery Toolset "unexpected keyword argument"

ADK's built-in BigQueryToolset parameters change between versions. Check the actual signature:
```python
import inspect
from google.adk.tools.bigquery import BigQueryToolset
print(inspect.signature(BigQueryToolset.__init__))
```

If built-in toolset does not work, use custom function tools with google.cloud.bigquery directly.

### Eval set not showing in web UI

The file must:
- Be in the agent directory (e.g., `ecom_agent/`), not a subdirectory
- End with `.evalset.json`
- Follow the EvalSet pydantic schema (eval_set_id + eval_cases)

### Token expiration

The gcloud access token expires after ~1 hour. If queries start failing, restart the agent to get a fresh token.
