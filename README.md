# BBS::Universal

![BBS::Universal Logo](files/files/BBS_Universal.png?raw=true "BBS::Universal")

A Perl based TCP-IP BBS catering to retro computers and that modem experience.

## CODE NOT EVEN CLOSE TO STABLE YET

Installing is at your own risk and likely will not be very useful to you at the moment, but if you want to track progress, then go ahead.

## INSTALLING

```bash
        perl Makefile.PL
        make
        make test
 [sudo] make install
        make veryclean
```

You will need a properly configured MySQL server.  You need to modify the "conf/bbs.rc" to reflect your MySQL installation and make sure the file is not world readable.  You also need to run the "sql/database_setup.sql" file.

## LICENSE AND COPYRIGHT

Copyright © 2023-2025 Richard Kelsch

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License Version 3 as published by the Free Software Foundation.

See the LICENSE file for a copy of this license.

