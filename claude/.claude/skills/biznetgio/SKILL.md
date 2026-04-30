---
name: biznetgio
description: Use when managing Biznet Gio cloud infrastructure — bare metal servers, NEO Lite/Pro VMs, object storage, elastic storage, additional IPs, keypairs, snapshots, disks, and buckets via the biznetgio CLI.
---

# biznetgio CLI

CLI for Biznet Gio Portal API. Installed globally via mise. Auth via `BIZNETGIO_API_KEY` env var (already set).

```bash
biznetgio [--api-key <key>] [--output table|json] <command>
```

## Commands Overview

**bare metal:** `metal` — servers, keypairs, products, states, OpenVPN
**VMs:** `neolite`, `neolite-pro` — instances, keypairs, snapshots, disks
**Storage:** `elastic-storage`, `object-storage` — quotas, credentials, buckets, objects
**Networking:** `additional-ip` — assign/unassign IPs to metal accounts

## metal

```bash
biznetgio metal list [--page N --per-page N]
biznetgio metal detail <account_id>
biznetgio metal create [options]          # --product-id, --label, --keypair-id, --os-id
biznetgio metal delete <account_id>
biznetgio metal update-label --label <l> <account_id>
biznetgio metal state <account_id>
biznetgio metal set-state <account_id> <state>  # see: metal states
biznetgio metal rebuild [options] <account_id>
biznetgio metal openvpn
biznetgio metal products
biznetgio metal product <product_id>
biznetgio metal product-os <product_id>
biznetgio metal rebuild-os <account_id>
biznetgio metal states
biznetgio metal keypair list|create|import|delete
```

## neolite / neolite-pro

Same interface for both; replace `neolite` with `neolite-pro`:

```bash
biznetgio neolite list [options]
biznetgio neolite detail <account_id>
biznetgio neolite create [options]
biznetgio neolite delete <account_id>
biznetgio neolite vm-details <account_id>
biznetgio neolite set-state <account_id> <state>
biznetgio neolite rename --name <n> <account_id>
biznetgio neolite rebuild [options] <account_id>
biznetgio neolite change-keypair [options] <account_id>
biznetgio neolite change-package-options <account_id>
biznetgio neolite change-package [options] <account_id>
biznetgio neolite storage-options <account_id>
biznetgio neolite upgrade-storage [options] <account_id>
biznetgio neolite migrate-to-pro-products <account_id>  # neolite only
biznetgio neolite migrate-to-pro [options] <account_id>  # neolite only
biznetgio neolite products
biznetgio neolite product <product_id>
biznetgio neolite product-os <product_id>
biznetgio neolite product-ip <product_id>

# Keypairs
biznetgio neolite keypair list|create|import|delete

# Snapshots
biznetgio neolite snapshot list|detail|create|create-instance|restore|delete|products|product

# Disks
biznetgio neolite disk list|detail|create|upgrade|delete|products|product
```

## elastic-storage

```bash
biznetgio elastic-storage list [options]
biznetgio elastic-storage detail <account_id>
biznetgio elastic-storage create [options]
biznetgio elastic-storage upgrade --size <n> <account_id>
biznetgio elastic-storage change-package [options] <account_id>
biznetgio elastic-storage delete <account_id>
biznetgio elastic-storage products
biznetgio elastic-storage product <product_id>
```

## additional-ip

```bash
biznetgio additional-ip list
biznetgio additional-ip detail <account_id>
biznetgio additional-ip create [options]
biznetgio additional-ip delete <account_id>
biznetgio additional-ip regions
biznetgio additional-ip products
biznetgio additional-ip product <product_id>
biznetgio additional-ip assignments <metal_account_id>
biznetgio additional-ip assigns <account_id>
biznetgio additional-ip assign [options] <account_id>
biznetgio additional-ip assign-detail <account_id> <metal_account_id>
biznetgio additional-ip unassign <account_id> <metal_account_id>
```

## object-storage

```bash
biznetgio object-storage list [options]
biznetgio object-storage detail <account_id>
biznetgio object-storage create [options]
biznetgio object-storage delete <account_id>
biznetgio object-storage upgrade-quota [options] <account_id>
biznetgio object-storage products
biznetgio object-storage product <product_id>

# Credentials
biznetgio object-storage credential list <account_id>
biznetgio object-storage credential create <account_id>
biznetgio object-storage credential update [options] <account_id> <access_key>
biznetgio object-storage credential delete <account_id> <access_key>

# Buckets
biznetgio object-storage bucket list <account_id>
biznetgio object-storage bucket create [options] <account_id>
biznetgio object-storage bucket info <account_id> <bucket_name>
biznetgio object-storage bucket usage <account_id> <bucket_name>
biznetgio object-storage bucket set-acl [options] <account_id> <bucket_name>
biznetgio object-storage bucket delete <account_id> <bucket_name>

# Objects
biznetgio object-storage object list <account_id> <bucket_name> [directory]
biznetgio object-storage object info <account_id> <bucket_name> <path>
biznetgio object-storage object download <account_id> <bucket_name> <object_name>
biznetgio object-storage object url [options] <account_id> <bucket_name> <object_name>
biznetgio object-storage object copy <account_id> <bucket_name> <to_bucket> <object_name>
biznetgio object-storage object move <account_id> <bucket_name> <to_bucket> <object_name>
biznetgio object-storage object mkdir <account_id> <bucket_name> <directory>
biznetgio object-storage object upload <account_id> <bucket_name> [directory]
biznetgio object-storage object set-acl [options] <account_id> <bucket_name> <path>
biznetgio object-storage object delete <account_id> <bucket_name> <path>
```

## Tips

- Use `--output json` for scripting; pipe through `jq` for field extraction
- Get flag details: `biznetgio <command> <subcommand> --help`
- `account_id` is the resource identifier returned by `list` commands
- Discover products before creating: run `products` to get valid `product_id` values
- For VM creation: chain `products` → `product-os` → `create`
