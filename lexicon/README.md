# Lexicon - Package Manager for CC:Tweaked

Lexicon is a lightweight package manager for ComputerCraft: Tweaked (CC:T) that simplifies the process of installing, managing, and updating Lua programs and libraries. It provides dependency management, automatic updates, and a centralized repository of packages.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Configuration](#configuration)
- [Package Structure](#package-structure)
- [Creating Packages](#creating-packages)
- [Dependency Management](#dependency-management)
- [Advanced Usage](#advanced-usage)

## Overview

Lexicon provides a simple command-line interface for managing CC:Tweaked packages. It features:

- **Package Installation**: Download and install programs and libraries from a centralized repository
- **Dependency Management**: Automatically resolves and installs package dependencies
- **Update System**: Keep all installed programs up-to-date with a single command
- **Package Removal**: Clean uninstallation with automatic cleanup of unused dependencies
- **Repository-based**: All packages are hosted on GitHub and managed through a central database

## Installation

Install lexicon by running this command in a ComputerCraft terminal:

```shell
pastebin get e84jWWbn lexicon
```

This downloads the lexicon program to your computer. You can then run it directly by name:

```shell
lexicon
```

**Note:** In CC:Tweaked, you can run `.lua` files by just using their basename without the extension. The shell automatically finds and executes `lexicon.lua` when you type `lexicon`.

## Quick Start

Here's a quick example to get you started:

```shell
# List all available packages
lexicon list

# Install a package (e.g., package-example)
lexicon get package-example

# Run the installed program
package-example

# List installed packages
lexicon list-installed

# Update all installed programs
lexicon upgrade

# Remove a package
lexicon remove package-example
```

## Commands

Lexicon supports the following commands:

### `get <package>`

Downloads and installs a package from the lexicon repository, including all its dependencies.

```shell
lexicon get <package-name>
```

**Example:**
```shell
lexicon get quarry
```

This command:
- Downloads the specified package and its dependencies
- Installs files to appropriate locations (programs to root, libraries to `/usr/lib/`)
- Updates the local package database
- Displays progress and any errors

### `remove <package>`

Uninstalls a package and removes any dependencies that are no longer needed by other packages.

```shell
lexicon remove <package-name>
```

**Example:**
```shell
lexicon remove quarry
```

**Note:** If a package is still required by other installed packages, lexicon will prevent its removal and show which packages depend on it.

### `list`

Lists all available packages in the lexicon repository.

```shell
lexicon list
```

Output shows:
- **Libraries** (in gray): Reusable code modules installed to `/usr/lib/`
- **Programs** (in green): Executable programs installed to the root directory

### `list-installed`

Shows all packages currently installed on the computer.

```shell
lexicon list-installed
```

### `upgrade`

Updates all installed **programs** (not libraries) and the lexicon tool itself to their latest versions.

```shell
lexicon upgrade
```

**Note:** Libraries are not automatically updated to prevent breaking changes. They are updated when their dependent programs are updated.

## Configuration

Lexicon uses ComputerCraft's settings API for configuration. The following settings can be customized:

### `lexicon.selfUrl`

URL to the lexicon program for self-updates.

- **Default:** `https://raw.githubusercontent.com/alexfayers/cc-24/<branch>/lexicon/lexicon.lua`
- **Type:** string

### `lexicon.dbUrl`

URL to the package database (manifest).

- **Default:** `https://raw.githubusercontent.com/alexfayers/cc-24/<branch>/lexicon/lexicon-db.json`
- **Type:** string

### `lexicon.dbPath`

Local path where the package database is stored.

- **Default:** `/.lexicon/db.json`
- **Type:** string

### `lexicon.gitBranch`

Git branch to use when downloading packages.

- **Default:** `main`
- **Type:** string

**Example - Changing the branch:**
```lua
settings.set("lexicon.gitBranch", "dev")
settings.save()
```

## Package Structure

Packages are defined in the `lexicon-db.json` file and can be one of two types:

### Package Types

1. **Programs**: Executable programs that users run directly
   - Installed to the root directory
   - Can be updated with the `upgrade` command
   - Examples: `quarry`, `storage2`, `farm`

2. **Libraries**: Reusable code modules
   - Installed to `/usr/lib/`
   - Used as dependencies by programs
   - Examples: `lib-logging`, `lib-turtle`, `class-lua`

### Package Definition Format

Each package in `lexicon-db.json` has the following structure:

```json
{
  "package-name": {
    "description": "A brief description of the package",
    "version": "1.0.0",
    "files": [
      [
        "https://raw.githubusercontent.com/alexfayers/cc-24/<branch>/path/to/source.lua",
        "/path/to/destination.lua"
      ]
    ],
    "dependencies": ["dependency1", "dependency2"],
    "usage": "How to run this program (for programs only)"
  }
}
```

**Fields:**
- `description`: Brief description of what the package does
- `version`: Semantic version number
- `files`: Array of `[source_url, destination_path]` pairs
- `dependencies`: Array of package names this package depends on
- `usage`: (Programs only) Instructions for running the program

## Creating Packages

To create a new package for lexicon:

### 1. Organize Your Code

Place your code in the appropriate directory:
- Programs: `packages/program/your-package/`
- Libraries: `packages/library/your-package/`

### 2. Add to the Database

Edit `lexicon/lexicon-db.json` and add your package definition:

**For a program:**
```json
{
  "packages": {
    "program": {
      "your-package": {
        "description": "Description of your program",
        "version": "1.0.0",
        "files": [
          [
            "https://raw.githubusercontent.com/alexfayers/cc-24/<branch>/packages/program/your-package/main.lua",
            "your-package.lua"
          ]
        ],
        "dependencies": ["lib-logging"],
        "usage": "'your-package'"
      }
    }
  }
}
```

**For a library:**
```json
{
  "packages": {
    "library": {
      "your-lib": {
        "description": "Description of your library",
        "version": "1.0.0",
        "files": [
          [
            "https://raw.githubusercontent.com/alexfayers/cc-24/<branch>/packages/library/your-lib/module.lua",
            "/usr/lib/your-lib/module.lua"
          ]
        ],
        "dependencies": []
      }
    }
  }
}
```

### 3. Test Your Package

```shell
lexicon get your-package
```

### 4. Best Practices

- **Version your packages**: Use semantic versioning (MAJOR.MINOR.PATCH)
- **Document dependencies**: Only list direct dependencies
- **Test installation**: Test on a fresh computer before committing
- **Add usage information**: Include clear instructions for programs
- **Follow naming conventions**: Use lowercase with hyphens for package names

## Dependency Management

Lexicon automatically handles dependencies:

### Installation

When you install a package, lexicon:
1. Checks if the package exists in the repository
2. Recursively downloads all dependencies
3. Installs files to the correct locations
4. Updates the local database with package information

### Removal

When you remove a package, lexicon:
1. Removes the package files
2. Checks each dependency
3. Removes dependencies that are no longer needed by any other package
4. Prevents removal if the package is still required by others

### Shared Dependencies

Multiple packages can share the same dependencies. Lexicon tracks which packages use which files and only removes files when no packages depend on them.

**Example:**
```
quarry depends on: lib-turtle, lib-logging
farm depends on: lib-turtle, lib-logging

If you remove quarry:
- lib-turtle and lib-logging are NOT removed (still used by farm)

If you then remove farm:
- lib-turtle and lib-logging ARE removed (no longer used)
```

## Advanced Usage

### Using Libraries in Your Code

To use a lexicon library in your program:

```lua
-- Add the library path to Lua's package search path
package.path = package.path .. ";/usr/lib/?.lua"

-- Require the library
local logging = require("lexicon-lib.lib-logging")
local logger = logging.getLogger("MyProgram")

-- Use the library
logger:info("Hello from my program!")
```

### Auto-Update on Startup

Install the `autoupdate` package to automatically update all programs on computer startup:

```shell
lexicon get autoupdate
```

This creates a `startup.lua` file that runs `lexicon upgrade` on boot.

### Parallel Downloads

Lexicon uses parallel downloads to speed up installation:
- Downloads multiple files simultaneously (up to 8 concurrent connections)
- Retries failed downloads automatically
- Shows progress for each package and dependency

### Cache Busting

Lexicon adds a timestamp parameter to all HTTP requests to prevent caching issues:

```lua
url = url .. "?t=" .. os.epoch("utc")
```

This ensures you always get the latest version of packages and the database.

### Local Database

Lexicon maintains a local database at `/.lexicon/db.json` that tracks:
- Installed packages
- Package versions
- Installed files for each package
- Dependencies for each package

This database is automatically updated when you install or remove packages.

## Troubleshooting

### Package Not Found

If you get a "Package not found" error:
- Check that the package name is spelled correctly
- Run `lexicon list` to see all available packages
- Ensure you have an internet connection

### Failed to Download

If downloads fail:
- Check your internet connection
- Verify the repository URLs in settings
- Try again (lexicon retries automatically up to 3 times)

### Permission Errors

If you get permission errors:
- Ensure you have write access to the installation directories
- Check that files aren't being used by running programs

### Dependency Conflicts

If a package can't be removed:
- Check which packages depend on it with the error message
- Remove dependent packages first
- Or keep the package installed

## Contributing

To contribute packages or improvements to lexicon:

1. Fork the repository
2. Add your package to `lexicon/lexicon-db.json`
3. Place your code in the appropriate `packages/` subdirectory
4. Test your package installation
5. Submit a pull request

## License

Part of the cc-24 project by alexfayers.

