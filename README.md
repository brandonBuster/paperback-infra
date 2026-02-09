# Alpaca Paper Trading API

Scaffolding for an Alpaca paper trading API with buy/sell order placement. Runs on Azure Functions, provisioned via Terraform with secure, minimal infrastructure.

## Architecture

- **API**: Python Azure Functions (HTTP trigger)
- **Secrets**: Azure Key Vault (Managed Identity, no credentials in code)
- **Compute**: Consumption plan (pay per execution)

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local) (for local dev and deploy)
- [Alpaca paper trading account](https://alpaca.markets/) and API keys

## Infrastructure (Terraform)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After apply, add your Alpaca keys to Key Vault:

```bash
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name ALPACA-API-KEY --value "<your-key>"
az keyvault secret set --vault-name <KEY_VAULT_NAME> --name ALPACA-SECRET-KEY --value "<your-secret>"
```

Use the `key_vault_name` output from Terraform.

## Deploy the API

```bash
cd api
func azure functionapp publish <FUNCTION_APP_NAME> --python
```

Use the `function_app_name` output from Terraform.

## API Usage

**Endpoint**: `POST https://<function-app>.azurewebsites.net/api/orders`

**Auth**: Function key (default). Get from Azure Portal → Function App → Functions → orders → Function Keys.

**Request body**:

```json
{
  "action": "buy",
  "symbol": "AAPL",
  "quantity": 10,
  "target_price": 150.50
}
```

| Parameter     | Type   | Required | Description                         |
|---------------|--------|----------|-------------------------------------|
| `action`      | string | Yes      | `"buy"` or `"sell"`                 |
| `symbol`      | string | Yes      | Ticker (e.g. `AAPL`)                |
| `quantity`    | number | Yes      | Order size                          |
| `target_price`| number | Yes      | Limit price for the order           |

**Example**:

```bash
curl -X POST "https://<function-app>.azurewebsites.net/api/orders?code=<FUNCTION_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"action":"buy","symbol":"AAPL","quantity":10,"target_price":150.50}'
```

## Local Development

1. Copy `local.settings.json.example` to `local.settings.json` and fill in Alpaca keys.
2. Run: `func start` (from `api/`)
3. Test: `curl -X POST http://localhost:7071/api/orders -H "Content-Type: application/json" -d '{"action":"buy","symbol":"AAPL","quantity":1,"target_price":150}'`

## Project Structure

```
alpaca-paper-trading/
├── api/
│   ├── function_app.py      # Orders endpoint
│   ├── host.json
│   ├── requirements.txt
│   └── local.settings.json.example
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
└── README.md
```
