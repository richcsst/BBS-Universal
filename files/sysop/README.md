# Creating Custom Menu Files

The files in "files/sysop/" are specifically for the local SysOp mode.  ALL are in ANSI format and thus will always have the "ANS" suffix.

## Format

Custom menus follow a specific format

* Menu descriptors (KEY|COMMAND|COLOR|DESCRIPTION)
* Divider "---"
* Text header

### Menu Descriptors

* KEY          - A single key used to activate the feature.  It is case insensitive.
* COMMAND      - The specific command token to activate the feature.  Use only the token name
* COLOR        - The color of the menu choice.
* DESCRIPTION  - The text to be displayed after the menu option

Note: All menu keys will be sorted on output

### Divider

The divider MUST be "---" on a line by itself.  This signals to the menu processor the end of the menu descriptors.

### Text Header

This is the actual menu text shown above the actual menu options when parsed and shown.  The text can have embedded tokens appropriate to the text mode the file is created for.

## Sample

```
# Key | Command | Color | Description
1|SYSOP LOGIN SYSOP|WHITE|Connect as user SysOp
2|SYSOP LOGIN|WHITE|Connect as another user
B|SYSOP BBS LISTINGS MANAGER|BRIGHT BLUE|BBS Listings Manager
D|SYSOP STATISTICS|MAGENTA|Display Statistics
E|SYSOP SHOW ENVIRONMENT|GREEN|Show Environmental Variables
F|SYSOP FILE MANAGER|YELLOW|File Manager
L|SYSOP LIST COMMANDS|COLOR 202|Commands & Tokens Reference
R|SYSOP RESTART|WHITE|Restart BBS
S|SYSOP SETTINGS|COLOR 125|Change System Settings
U|SYSOP USER MANAGER|CYAN|User Manager
X|SYSOP SHUTDOWN|WHITE|Shutdown BBS
---
[% RED     %]     #[% BRIGHT WHITE %]  ____            _                   __  __[% RESET %]
[% YELLOW  %]    ##[% BRIGHT WHITE %] / ___| _   _ ___| |_ ___ _ __ ___   |  \/  | ___ _ __  _   _[% RESET %]
[% GREEN   %]   ###[% BRIGHT WHITE %] \___ \| | | / __| __/ _ \ '_ ` _ \  | |\/| |/ _ \ '_ \| | | |[% RESET %]
[% MAGENTA %]  ####[% BRIGHT WHITE %]  ___) | |_| \__ \ ||  __/ | | | | | | |  | |  __/ | | | |_| |[% RESET %]
[% BLUE    %] #####[% BRIGHT WHITE %] |____/ \__, |___/\__\___|_| |_| |_| |_|  |_|\___|_| |_|\__,_|[% RESET %]
[% CYAN    %]######[% BRIGHT WHITE %]        |___/[% RESET %]
```
