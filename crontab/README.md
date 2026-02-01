# Crontab

No cron jobs are currently configured on this machine.

## Adding future cron jobs

Edit the crontab with:

```bash
crontab -e
```

Template entry:

```text
# ┌───────────── minute (0-59)
# │ ┌───────────── hour (0-23)
# │ │ ┌───────────── day of month (1-31)
# │ │ │ ┌───────────── month (1-12)
# │ │ │ │ ┌───────────── day of week (0-6, Sun=0)
# │ │ │ │ │
# * * * * * command
```

When adding jobs, document them here and optionally export with `crontab -l > crontab/crontab.bak`.
