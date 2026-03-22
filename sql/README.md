# BBS::Universal SQL File

![BBS::Universal Logo](../files/files/BBS/BBS_Universal.png?raw=true "BBS::Universal")

## SQL File

Use this file to create the database template

```bash
sudo mysql -u root --skip-password < sql/database_setup.sql
```

You need to create the appropriate user account and permissions according to ```bbs.rc``` definitions.
