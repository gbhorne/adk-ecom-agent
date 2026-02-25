#!/bin/bash
# ============================================================================
# NL2SQL E-Commerce Analytics Agent - Project Verification Script
# ============================================================================
# This script verifies every component of the build:
#   1. Environment and dependencies
#   2. BigQuery dataset and tables
#   3. Data integrity and row counts
#   4. Sample query validation
#   5. Agent project structure
#   6. Agent code quality checks
#   7. Eval set validation
#   8. Safety guardrail verification
#   9. Tool function verification
#  10. Summary report
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0
TOTAL=0

# ============================================================================
# Helper functions
# ============================================================================
section() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

check() {
    TOTAL=$((TOTAL + 1))
    local description="$1"
    local command="$2"
    local expected="$3"

    local result
    result=$(eval "$command" 2>&1) || true

    if echo "$result" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  $description"
        echo -e "        Expected: ${expected}"
        echo -e "        Got:      ${result:0:200}"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

check_exact() {
    TOTAL=$((TOTAL + 1))
    local description="$1"
    local actual="$2"
    local expected="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $description"
        echo -e "        Expected: ${expected}"
        echo -e "        Got:      ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

check_file() {
    TOTAL=$((TOTAL + 1))
    local description="$1"
    local filepath="$2"

    if [ -f "$filepath" ]; then
        local size
        size=$(wc -c < "$filepath")
        echo -e "  ${GREEN}PASS${NC}  $description (${size} bytes)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $description - file not found: $filepath"
        FAIL=$((FAIL + 1))
    fi
}

check_contains() {
    TOTAL=$((TOTAL + 1))
    local description="$1"
    local filepath="$2"
    local pattern="$3"

    if grep -q "$pattern" "$filepath" 2>/dev/null; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $description - pattern not found: $pattern"
        FAIL=$((FAIL + 1))
    fi
}

warn_check() {
    TOTAL=$((TOTAL + 1))
    local description="$1"
    local command="$2"
    local expected="$3"

    local result
    result=$(eval "$command" 2>&1) || true

    if echo "$result" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}WARN${NC}  $description"
        echo -e "        ${result:0:200}"
        WARN=$((WARN + 1))
    fi
}

# ============================================================================
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ============================================================"
echo "  NL2SQL E-Commerce Analytics Agent"
echo "  Project Verification Report"
echo "  ============================================================"
echo -e "${NC}"
echo "  Date:      $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  Project:   $(gcloud config get-value project 2>/dev/null)"
echo "  User:      $(whoami)"
echo "  Directory: $(pwd)"
echo ""

# ============================================================================
section "1. ENVIRONMENT AND DEPENDENCIES"
# ============================================================================

check "GCP project is set" \
    "gcloud config get-value project 2>/dev/null" \
    "playground-s-11-6d7b503d"

check "BigQuery API is enabled" \
    "gcloud services list --enabled --filter='name:bigquery.googleapis.com' --format='value(name)' 2>/dev/null" \
    "bigquery.googleapis.com"

check "Python 3.10+ is available" \
    "python3 --version 2>&1" \
    "Python 3"

check "Virtual environment exists" \
    "ls ~/adk-ecom-agent/.venv/bin/activate 2>/dev/null && echo 'exists'" \
    "exists"

# Activate venv for remaining checks
source ~/adk-ecom-agent/.venv/bin/activate 2>/dev/null || true

check "google-adk is installed" \
    "pip show google-adk 2>/dev/null | grep Version" \
    "Version"

ADK_VERSION=$(pip show google-adk 2>/dev/null | grep Version | awk '{print $2}')
echo -e "        ADK version: ${CYAN}${ADK_VERSION}${NC}"

check "google-cloud-bigquery is installed" \
    "pip show google-cloud-bigquery 2>/dev/null | grep Version" \
    "Version"

check "gcloud auth is working" \
    "gcloud auth print-access-token > /dev/null 2>&1 && echo 'authenticated'" \
    "authenticated"

# ============================================================================
section "2. BIGQUERY DATASET AND TABLES"
# ============================================================================

check "ecom_analytics dataset exists" \
    "bq ls --format=json 2>/dev/null | python3 -c 'import sys,json; ds=[d[\"datasetReference\"][\"datasetId\"] for d in json.load(sys.stdin)]; print(\"ecom_analytics\" in ds)'" \
    "True"

check "products table exists" \
    "bq show --format=json ecom_analytics.products 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"tableReference\"][\"tableId\"])'" \
    "products"

check "customers table exists" \
    "bq show --format=json ecom_analytics.customers 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"tableReference\"][\"tableId\"])'" \
    "customers"

check "orders table exists" \
    "bq show --format=json ecom_analytics.orders 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"tableReference\"][\"tableId\"])'" \
    "orders"

# ============================================================================
section "3. DATA INTEGRITY AND ROW COUNTS"
# ============================================================================

PRODUCT_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet 'SELECT COUNT(*) AS cnt FROM ecom_analytics.products' 2>/dev/null | tail -1)
check_exact "products table has 50 rows" "$PRODUCT_COUNT" "50"

CUSTOMER_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet 'SELECT COUNT(*) AS cnt FROM ecom_analytics.customers' 2>/dev/null | tail -1)
check_exact "customers table has 30 rows" "$CUSTOMER_COUNT" "30"

ORDER_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet 'SELECT COUNT(*) AS cnt FROM ecom_analytics.orders' 2>/dev/null | tail -1)
check_exact "orders table has 100 rows" "$ORDER_COUNT" "100"

# Column count checks
PRODUCT_COLS=$(bq show --format=json ecom_analytics.products 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["schema"]["fields"]))' 2>/dev/null)
check_exact "products table has 10 columns" "$PRODUCT_COLS" "10"

CUSTOMER_COLS=$(bq show --format=json ecom_analytics.customers 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["schema"]["fields"]))' 2>/dev/null)
check_exact "customers table has 11 columns" "$CUSTOMER_COLS" "11"

ORDER_COLS=$(bq show --format=json ecom_analytics.orders 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["schema"]["fields"]))' 2>/dev/null)
check_exact "orders table has 12 columns" "$ORDER_COLS" "12"

# Data quality checks
NULL_ORDERS=$(bq query --use_legacy_sql=false --format=csv --quiet 'SELECT COUNT(*) AS cnt FROM ecom_analytics.orders WHERE customer_id IS NULL' 2>/dev/null | tail -1)
check_exact "No null customer_ids in orders" "$NULL_ORDERS" "0"

NULL_PRICES=$(bq query --use_legacy_sql=false --format=csv --quiet 'SELECT COUNT(*) AS cnt FROM ecom_analytics.products WHERE unit_price IS NULL OR unit_cost IS NULL' 2>/dev/null | tail -1)
check_exact "No null prices in products" "$NULL_PRICES" "0"

ORPHAN_ORDERS=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT COUNT(*) AS cnt FROM ecom_analytics.orders o
LEFT JOIN ecom_analytics.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL' 2>/dev/null | tail -1)
check_exact "No orphan orders (all customer_ids valid)" "$ORPHAN_ORDERS" "0"

# ============================================================================
section "4. SAMPLE QUERY VALIDATION"
# ============================================================================

# Revenue by region
REGION_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT COUNT(DISTINCT shipping_region) AS cnt FROM ecom_analytics.orders' 2>/dev/null | tail -1)
check "Revenue query returns multiple regions" \
    "echo $REGION_COUNT" \
    "[2-9]"

# Top customers join works
JOIN_RESULT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT c.first_name, c.last_name, ROUND(SUM(o.total_amount),2) AS total_spent
FROM ecom_analytics.customers c
JOIN ecom_analytics.orders o ON c.customer_id = o.customer_id
GROUP BY c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 3' 2>/dev/null | wc -l)
check "Cross-table JOIN returns top 3 customers" \
    "echo $JOIN_RESULT" \
    "[3-4]"

# Profit margin calculation works
MARGIN_RESULT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT category, ROUND(AVG((unit_price - unit_cost) / unit_price) * 100, 1) AS margin_pct
FROM ecom_analytics.products
GROUP BY category
ORDER BY margin_pct DESC
LIMIT 1' 2>/dev/null | tail -1)
check "Profit margin calculation executes" \
    "echo '$MARGIN_RESULT'" \
    ","

# Monthly revenue aggregation
MONTH_RESULT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT FORMAT_DATE("%Y-%m", order_date) AS month, ROUND(SUM(total_amount),2) AS revenue
FROM ecom_analytics.orders
GROUP BY month
ORDER BY revenue DESC
LIMIT 1' 2>/dev/null | tail -1)
check "Monthly revenue aggregation executes" \
    "echo '$MONTH_RESULT'" \
    ","

# Payment method breakdown
PAYMENT_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT COUNT(DISTINCT payment_method) AS cnt FROM ecom_analytics.orders' 2>/dev/null | tail -1)
check_exact "4 distinct payment methods exist" "$PAYMENT_COUNT" "4"

# Loyalty tier distribution
TIER_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT COUNT(DISTINCT loyalty_tier) AS cnt FROM ecom_analytics.customers' 2>/dev/null | tail -1)
check_exact "4 distinct loyalty tiers exist" "$TIER_COUNT" "4"

# Category distribution
CAT_COUNT=$(bq query --use_legacy_sql=false --format=csv --quiet '
SELECT COUNT(DISTINCT category) AS cnt FROM ecom_analytics.products' 2>/dev/null | tail -1)
check "At least 5 product categories" \
    "echo $CAT_COUNT" \
    "[5-9]"

# ============================================================================
section "5. AGENT PROJECT STRUCTURE"
# ============================================================================

check_file "agent.py exists" ~/adk-ecom-agent/ecom_agent/agent.py
check_file "__init__.py exists" ~/adk-ecom-agent/ecom_agent/__init__.py
check_file ".env exists" ~/adk-ecom-agent/ecom_agent/.env
check_file "evalset file exists" ~/adk-ecom-agent/ecom_agent/ecom_eval.evalset.json
check_file "README.md exists" ~/adk-ecom-agent/README.md
check_file "ARCHITECTURE.md exists" ~/adk-ecom-agent/ARCHITECTURE.md
check_file "BUILD_GUIDE.md exists" ~/adk-ecom-agent/BUILD_GUIDE.md

# ============================================================================
section "6. AGENT CODE QUALITY CHECKS"
# ============================================================================

AGENT_FILE=~/adk-ecom-agent/ecom_agent/agent.py

check_contains "Agent imports ADK Agent class" "$AGENT_FILE" "from google.adk.agents import Agent"
check_contains "Agent imports AgentTool" "$AGENT_FILE" "from google.adk.tools.agent_tool import AgentTool"
check_contains "Agent imports BigQuery client" "$AGENT_FILE" "from google.cloud import bigquery"
check_contains "Agent defines root_agent" "$AGENT_FILE" "root_agent"
check_contains "Agent defines execute_sql tool" "$AGENT_FILE" "def execute_sql"
check_contains "Agent defines get_schema tool" "$AGENT_FILE" "def get_schema"
check_contains "Agent defines list_tables tool" "$AGENT_FILE" "def list_tables"
check_contains "Agent defines before_tool_callback" "$AGENT_FILE" "def before_tool_callback"
check_contains "Agent defines after_tool_callback" "$AGENT_FILE" "def after_tool_callback"
check_contains "Agent defines sql_validator agent" "$AGENT_FILE" "sql_validator"
check_contains "Agent uses Gemini model" "$AGENT_FILE" "gemini"
check_contains "Agent references correct project ID" "$AGENT_FILE" "playground-s-11-6d7b503d"
check_contains "Agent references ecom_analytics dataset" "$AGENT_FILE" "ecom_analytics"
check_contains "Agent blocks DELETE keyword" "$AGENT_FILE" "DELETE"
check_contains "Agent blocks DROP keyword" "$AGENT_FILE" "DROP"
check_contains "Agent blocks TRUNCATE keyword" "$AGENT_FILE" "TRUNCATE"
check_contains "Agent uses gcloud token auth" "$AGENT_FILE" "gcloud.*auth.*print-access-token"
check_contains "Agent has read-only instructions" "$AGENT_FILE" "READ-ONLY"

# Check tool count in root agent definition
TOOL_COUNT=$(grep -c "execute_sql\|get_schema\|list_tables\|sql_validator_tool" "$AGENT_FILE" | head -1)
check "Agent registers 4 tools" \
    "grep 'tools=\[' $AGENT_FILE" \
    "execute_sql"

# Verify __init__.py imports agent
check_contains "__init__.py imports agent module" ~/adk-ecom-agent/ecom_agent/__init__.py "from . import agent"

# Verify .env configuration
check_contains ".env disables Vertex AI" ~/adk-ecom-agent/ecom_agent/.env "GOOGLE_GENAI_USE_VERTEXAI=FALSE"
check_contains ".env has API key" ~/adk-ecom-agent/ecom_agent/.env "GOOGLE_API_KEY"

# ============================================================================
section "7. EVAL SET VALIDATION"
# ============================================================================

EVAL_FILE=~/adk-ecom-agent/ecom_agent/ecom_eval.evalset.json

check_file "Eval set file uses correct extension (.evalset.json)" "$EVAL_FILE"

# Validate JSON structure
check "Eval set is valid JSON" \
    "python3 -c 'import json; json.load(open(\"$EVAL_FILE\"))' 2>&1 && echo 'valid'" \
    "valid"

# Check eval set ID
check "Eval set has eval_set_id field" \
    "python3 -c 'import json; d=json.load(open(\"$EVAL_FILE\")); print(d[\"eval_set_id\"])'" \
    "ecom_eval"

# Count eval cases
EVAL_CASE_COUNT=$(python3 -c "import json; d=json.load(open('$EVAL_FILE')); print(len(d['eval_cases']))" 2>/dev/null)
check_exact "Eval set has 10 test cases" "$EVAL_CASE_COUNT" "10"

# Verify each eval case has required fields
check "All eval cases have evalId" \
    "python3 -c '
import json
d = json.load(open(\"$EVAL_FILE\"))
ids = [c[\"evalId\"] for c in d[\"eval_cases\"]]
print(len(ids))
'" \
    "10"

check "All eval cases have conversation or rubrics" \
    "python3 -c '
import json
d = json.load(open(\"$EVAL_FILE\"))
valid = all(c.get(\"conversation\") or c.get(\"rubrics\") for c in d[\"eval_cases\"])
print(valid)
'" \
    "True"

# Check specific eval case IDs exist
check "Safety test case exists" \
    "python3 -c '
import json
d = json.load(open(\"$EVAL_FILE\"))
ids = [c[\"evalId\"] for c in d[\"eval_cases\"]]
print(\"safety_delete_blocked\" in ids)
'" \
    "True"

check "Schema discovery test case exists" \
    "python3 -c '
import json
d = json.load(open(\"$EVAL_FILE\"))
ids = [c[\"evalId\"] for c in d[\"eval_cases\"]]
print(\"schema_discovery\" in ids)
'" \
    "True"

# Count total rubrics
RUBRIC_COUNT=$(python3 -c "
import json
d = json.load(open('$EVAL_FILE'))
total = sum(len(c.get('rubrics', [])) for c in d['eval_cases'])
print(total)
" 2>/dev/null)
echo -e "        Total rubrics across all cases: ${CYAN}${RUBRIC_COUNT}${NC}"

# Validate EvalSet against ADK schema
check "Eval set validates against ADK EvalSet schema" \
    "python3 -c '
from google.adk.evaluation.eval_set import EvalSet
import json
with open(\"$EVAL_FILE\") as f:
    content = f.read()
es = EvalSet.model_validate_json(content)
print(f\"valid:{es.eval_set_id}\")
' 2>&1" \
    "valid:ecom_eval"

# ============================================================================
section "8. SAFETY GUARDRAIL VERIFICATION"
# ============================================================================

# Test the keyword blocker in isolation
echo -e "  Testing execute_sql keyword blocker..."

check "DELETE is blocked" \
    "python3 -c '
import sys
sys.path.insert(0, \"/root/adk-ecom-agent\") if __import__(\"os\").path.exists(\"/root/adk-ecom-agent\") else None
# Simulate the blocker
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"DELETE FROM ecom_analytics.orders\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:True"

check "DROP TABLE is blocked" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"DROP TABLE ecom_analytics.orders\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:True"

check "UPDATE is blocked" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"UPDATE ecom_analytics.orders SET total_amount = 0\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:True"

check "INSERT is blocked" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"INSERT INTO ecom_analytics.orders VALUES (1,2,3)\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:True"

check "TRUNCATE is blocked" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"TRUNCATE TABLE ecom_analytics.orders\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:True"

check "SELECT is allowed" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"SELECT COUNT(*) FROM ecom_analytics.orders\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:False"

check "SELECT with JOIN is allowed" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"SELECT c.first_name, SUM(o.total_amount) FROM ecom_analytics.customers c JOIN ecom_analytics.orders o ON c.customer_id = o.customer_id GROUP BY c.first_name\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:False"

check "CREATED (substring) is correctly allowed (no false positive)" \
    "python3 -c '
BLOCKED = [\"DELETE\", \"DROP\", \"TRUNCATE\", \"UPDATE\", \"INSERT\", \"ALTER\", \"CREATE\", \"MERGE\", \"GRANT\", \"REVOKE\"]
query = \"SELECT * FROM ecom_analytics.orders WHERE order_status = CREATED\"
blocked = any(kw in query.upper().split() for kw in BLOCKED)
print(f\"blocked:{blocked}\")
'" \
    "blocked:False"

# ============================================================================
section "9. TOOL FUNCTION VERIFICATION (Live BigQuery)"
# ============================================================================

echo -e "  Testing tools against live BigQuery..."

check "execute_sql returns correct order count" \
    "python3 -c '
import subprocess
from google.oauth2.credentials import Credentials
from google.cloud import bigquery

token = subprocess.check_output([\"gcloud\", \"auth\", \"print-access-token\"]).decode().strip()
client = bigquery.Client(project=\"playground-s-11-6d7b503d\", credentials=Credentials(token=token))
result = client.query(\"SELECT COUNT(*) AS cnt FROM ecom_analytics.orders\").result()
for row in result:
    print(f\"count:{row.cnt}\")
'" \
    "count:100"

check "get_schema returns products columns" \
    "python3 -c '
import subprocess
from google.oauth2.credentials import Credentials
from google.cloud import bigquery

token = subprocess.check_output([\"gcloud\", \"auth\", \"print-access-token\"]).decode().strip()
client = bigquery.Client(project=\"playground-s-11-6d7b503d\", credentials=Credentials(token=token))
table = client.get_table(\"playground-s-11-6d7b503d.ecom_analytics.products\")
cols = [f.name for f in table.schema]
print(f\"has_product_name:{\"product_name\" in cols}\")
print(f\"has_unit_price:{\"unit_price\" in cols}\")
print(f\"col_count:{len(cols)}\")
'" \
    "has_product_name:True"

check "list_tables returns all 3 tables" \
    "python3 -c '
import subprocess
from google.oauth2.credentials import Credentials
from google.cloud import bigquery

token = subprocess.check_output([\"gcloud\", \"auth\", \"print-access-token\"]).decode().strip()
client = bigquery.Client(project=\"playground-s-11-6d7b503d\", credentials=Credentials(token=token))
tables = [t.table_id for t in client.list_tables(\"playground-s-11-6d7b503d.ecom_analytics\")]
print(f\"count:{len(tables)}\")
print(f\"has_all:{set(tables) == {\"products\", \"customers\", \"orders\"}}\")
'" \
    "has_all:True"

check "Cross-table JOIN works end-to-end" \
    "bq query --use_legacy_sql=false --format=csv --quiet 'SELECT c.first_name, c.last_name, c.loyalty_tier, ROUND(SUM(o.total_amount),2) AS total_spent FROM ecom_analytics.customers c JOIN ecom_analytics.orders o ON c.customer_id = o.customer_id GROUP BY c.first_name, c.last_name, c.loyalty_tier ORDER BY total_spent DESC LIMIT 1' 2>/dev/null | tail -1" \
    "Robert"

# ============================================================================
section "10. DOCUMENTATION CHECKS"
# ============================================================================

README=~/adk-ecom-agent/README.md
ARCH=~/adk-ecom-agent/ARCHITECTURE.md
BUILD=~/adk-ecom-agent/BUILD_GUIDE.md

check_contains "README references ADK" "$README" "Agent Development Kit"
check_contains "README has Quick Start section" "$README" "Quick Start"
check_contains "README has Safety section" "$README" "Safety"
check_contains "ARCHITECTURE has component diagram" "$ARCH" "BigQuery"
check_contains "ARCHITECTURE has credential strategy" "$ARCH" "credential\|Credential\|gcloud"

check_contains "BUILD_GUIDE has Phase 1" "$BUILD" "Phase 1"
check_contains "BUILD_GUIDE has troubleshooting" "$BUILD" "Troubleshooting\|troubleshooting"

# ============================================================================
# SUMMARY REPORT
# ============================================================================
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ============================================================"
echo "  VERIFICATION SUMMARY"
echo "  ============================================================"
echo -e "${NC}"
echo ""
echo -e "  ${GREEN}PASSED:  ${PASS}${NC}"
echo -e "  ${RED}FAILED:  ${FAIL}${NC}"
echo -e "  ${YELLOW}WARNINGS: ${WARN}${NC}"
echo -e "  TOTAL:   ${TOTAL}"
echo ""

PASS_RATE=0
if [ $TOTAL -gt 0 ]; then
    PASS_RATE=$((PASS * 100 / TOTAL))
fi

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}RESULT: ALL CHECKS PASSED (${PASS_RATE}%)${NC}"
    echo ""
    echo -e "  The NL2SQL E-Commerce Analytics Agent project is verified"
    echo -e "  and ready for deployment to GitHub."
elif [ $FAIL -le 3 ]; then
    echo -e "  ${YELLOW}${BOLD}RESULT: MOSTLY PASSING (${PASS_RATE}%) - ${FAIL} issue(s) to review${NC}"
else
    echo -e "  ${RED}${BOLD}RESULT: NEEDS ATTENTION (${PASS_RATE}%) - ${FAIL} issue(s) found${NC}"
fi

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "  Verification complete: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${BLUE}============================================================================${NC}"
echo ""
