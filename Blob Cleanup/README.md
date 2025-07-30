# Azure Automation – Blob Cleanup Script

This repository contains a PowerShell script designed to run in an **Azure Automation Runbook**. The script automatically deletes the **oldest blobs** in an Azure Storage Account container while retaining the **10 most recently modified files**.

---

# Purpose

This Automation Runbook is useful for managing storage costs and keeping container size under control — particularly for workloads that generate regular backups or artifacts (e.g., database backups).

---

# How It Works

- Connects to Azure using a **Managed Identity**
- Lists all blobs in the specified storage container
- Sorts them by 'LastModified' date (descending)
- Retains the **10 newest blobs**
- Deletes all other (older) blobs