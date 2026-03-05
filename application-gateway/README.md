# Azure Application Gateway with Terraform

This folder contains a complete Terraform configuration for deploying an Azure Application Gateway with comprehensive features including listeners, routing rules, backend pools, health probes, and path-based routing.

## Features

This configuration includes:

- **Virtual Network**: A VNet with dedicated subnets for Application Gateway and backend resources
- **Public IP**: Static public IP address for the Application Gateway
- **Application Gateway**: Fully configured with:
  - Frontend IP configuration
  - Multiple frontend ports (HTTP:80, HTTPS:443)
  - Multiple backend address pools
  - Backend HTTP settings with health probes
  - HTTP/HTTPS listeners
  - Basic and path-based routing rules
  - URL path maps for routing traffic based on URL patterns
  - Health probes with customizable settings

## Architecture

```
Internet
    │
    ▼
Public IP
    │
    ▼
Application Gateway
    │
    ├─── Listener (HTTP:80) ──► Routing Rule ──► Backend Pool 1 (App1)
    │
    └─── Path-based Listener ──► URL Path Map
                                      │
                                      ├─── /app1/* ──► Backend Pool 1
                                      └─── /app2/* ──► Backend Pool 2
```

## Prerequisites

- Azure subscription
- Terraform >= 1.0
- Azure CLI (authenticated)
- Appropriate permissions to create resources in Azure

## Configuration

### Variables

Key variables you can customize in `terraform.tfvars`:

- `resource_group_name`: Name of the resource group (default: "rg-appgw-demo")
- `location`: Azure region (default: "eastus")
- `appgw_sku_name`: SKU name (default: "Standard_v2")
- `appgw_sku_tier`: SKU tier (default: "Standard_v2")
- `appgw_capacity`: Number of instances (default: 2)

See `terraform.tfvars.example` for all available variables.

## Usage

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Get Outputs

After deployment, retrieve important information:

```bash
terraform output
```

Key outputs include:
- Public IP address of the Application Gateway
- Resource IDs for integration with other services
- Subnet IDs for backend resources

## Routing Configuration

### Basic Routing

The configuration includes a basic routing rule that forwards all HTTP traffic on port 80 to the first backend pool.

### Path-Based Routing

Path-based routing is configured to route traffic based on URL paths:

- `/app1/*` → Backend Pool 1 (App1)
- `/app2/*` → Backend Pool 2 (App2)
- Default → Backend Pool 1

## Backend Configuration

### Adding Backend Targets

To add actual backend targets (VMs, AKS nodes, etc.), uncomment and modify the backend pool configuration in `main.tf`:

```hcl
backend_address_pool {
  name         = "backend-pool-app1"
  fqdns        = ["app1.example.com"]  # For FQDN-based backends
  ip_addresses = ["10.0.2.10"]         # For IP-based backends
}
```

### Health Probes

Two health probes are configured:

1. **health-probe-app1**: HTTP probe on `/health` endpoint
2. **health-probe-app2**: HTTPS probe with host name from backend settings

Customize the probe settings based on your application requirements.

## HTTPS Configuration

To enable HTTPS:

1. Uncomment the HTTPS listener section in `main.tf`
2. Uncomment the SSL certificate section
3. Provide your SSL certificate:

```hcl
ssl_certificate {
  name     = "appgw-ssl-cert"
  data     = filebase64("path/to/certificate.pfx")
  password = var.ssl_certificate_password
}
```

4. Update routing rules to use the HTTPS listener

## WAF Configuration

To enable Web Application Firewall (WAF):

1. Change SKU to WAF_v2:
   ```hcl
   appgw_sku_name = "WAF_v2"
   appgw_sku_tier = "WAF_v2"
   ```

2. Uncomment the WAF configuration section in `main.tf`:
   ```hcl
   waf_configuration {
     enabled          = true
     firewall_mode    = "Prevention"
     rule_set_type    = "OWASP"
     rule_set_version = "3.2"
   }
   ```

## Integration with AKS

To integrate with Azure Kubernetes Service:

1. Deploy your AKS cluster in the backend subnet
2. Add AKS node IPs or service IPs to the backend pool
3. Configure backend HTTP settings to match your service ports
4. Consider using the Application Gateway Ingress Controller (AGIC) for automated configuration

## Cost Considerations

- Application Gateway pricing is based on SKU, capacity, and data processed
- Standard_v2 SKU offers autoscaling capabilities
- Consider using autoscaling to optimize costs
- Review Azure pricing calculator for estimates

## Cleanup

To destroy all created resources:

```bash
terraform destroy
```

## Troubleshooting

### Common Issues

1. **Subnet size**: Ensure the Application Gateway subnet has enough IP addresses (minimum /24 recommended)
2. **Backend health**: Check backend health probes are returning successful status codes
3. **NSG rules**: Verify Network Security Groups allow required traffic
4. **SSL certificates**: Ensure certificates are valid and properly formatted

### Viewing Backend Health

After deployment, check backend health in the Azure Portal:
- Navigate to your Application Gateway
- Go to "Backend health"
- Review the health status of each backend pool

## Additional Resources

- [Azure Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [Terraform AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway)
- [Application Gateway Best Practices](https://docs.microsoft.com/azure/application-gateway/best-practices)

## Security Best Practices

- Use HTTPS listeners with valid SSL certificates
- Enable WAF for additional security
- Implement proper Network Security Groups
- Use managed identities for authentication
- Store SSL certificate passwords in Azure Key Vault
- Regularly update to the latest Terraform provider version
