# Creating Custom Menu Files

## Naming

The file must have the suffix that describes the text mode it will be used for processing.

* ANS - ANSI mode files
* ASC - ASCII mode files
* ATA - ATASCII mode (Atari) files
* PET - PETSCII mode (Commodore) files

## Format

Custom menus follow a specific format

* Menu descriptors (KEY|COMMAND|COLOR|ACCESS LEVEL|DESCRIPTION)
* Divider "---"
* Text header

### Menu Descriptors

* KEY          - A single key used to activate the feature.  It is case insensitive.
* COMMAND      - The specific command token to activate the feature.  Use only the token name
* COLOR        - The color of the menu choice.  This only works in ANSI and PETSCII text mode, but is still required for other modes.
* ACCESS LEVEL - The access level of the command.  The menu option will only be showed and acted upon if the user's access level is equal to or above the specified access level.
* DESCRIPTION  - The text to be displayed after the menu option

### Divider

The divider MUST be "---" on a line by itself.  This signals to the menu processor the end of the menu descriptors.

### Text Header

This is the actual menu text shown above the actual menu options when parsed and shown.
