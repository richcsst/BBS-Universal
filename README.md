### BBS::Universal

![BBS::Universal Logo](files/files/BBS_Universal.png?raw=true "BBS::Universal")

A Perl based TCP-IP BBS catering to retro computers and that modem experience.

## INSTALLING

```bash
        perl Makefile.PL
        make
        make test
 [sudo] make install
        make veryclean
```

## DATABASE

Typically MySQL is used, but you can use any database.  Just set your configuration accordingly.

For MySQL, please use the plugin "mysql_native_password" when creating the "bbssystem" user.  We do not use SSL with MySQL.

```bash
      CREATE USER 'bbssystem'@'%' IDENTIFIED WITH mysql_native_password BY 'yourpassword';
	  GRANT ALL PRIVILEGES ON BBSUniversal.* TO 'bbsystem'@'%';
```

If you want to enable SSL, well... you are on your own.  The connect code is in BBS::Universal::DB.pm and you must rebuild the installation.

## LICENSE AND COPYRIGHT

Copyright © 2023-2025 Richard Kelsch

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License Version 3 as published by the Free Software Foundation.

See the LICENSE file for a copy of this license.

