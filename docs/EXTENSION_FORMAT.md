# Summon Extension Format

## Directory Structure

```
~/Library/Application Support/Summon/extensions/
  my-extension/
    manifest.json      # Extension metadata
    search.sh          # Executable script (any language)
    icon.png           # Optional icon
```

## manifest.json

```json
{
  "name": "My Extension",
  "description": "Does something cool",
  "author": "Your Name",
  "version": "1.0.0",
  "keyword": "myext",
  "icon": "icon.png",
  "script": "search.sh"
}
```

### Fields

- **name** (required): Display name of the extension
- **description** (optional): Brief description
- **author** (optional): Creator name
- **version** (optional): Semantic version
- **keyword** (required): Trigger keyword (e.g., "gh", "ow")
- **icon** (optional): Path to icon file relative to extension directory
- **script** (required): Path to executable script relative to extension directory

## Script Interface

### Input

The script receives the user's query as the first argument:

```bash
#!/bin/bash
query="$1"
echo "User typed: $query" >&2  # Debug to stderr
```

### Output

Scripts must output JSON to stdout in this format:

```json
{
  "items": [
    {
      "title": "Result Title",
      "subtitle": "Optional description",
      "arg": "value-to-pass",
      "icon": {
        "path": "/path/to/icon.png"
      }
    }
  ]
}
```

### JSON Fields

#### Item Object

- **title** (required): Main text displayed
- **subtitle** (optional): Secondary description text
- **arg** (optional): Value passed when item is selected (URL to open, command to run, etc)
- **icon** (optional): Icon configuration object
- **valid** (optional, default: true): If false, item is not actionable
- **autocomplete** (optional): Text to autocomplete when Tab is pressed
- **quicklook** (optional): URL or file path for Quick Look preview

#### Icon Object

```json
{
  "path": "/path/to/image.png",
  "type": "fileicon"  // or "filetype"
}
```

Or simply:
```json
{
  "path": "icon.png"  // Relative to extension directory
}
```

### Supported Languages

Any executable script:
- **Bash/Zsh**: `#!/bin/bash`
- **Python**: `#!/usr/bin/env python3`
- **Node.js**: `#!/usr/bin/env node`
- **Ruby**: `#!/usr/bin/env ruby`
- **Compiled**: Any compiled binary

Just make sure the script is executable: `chmod +x search.sh`

## Examples

### Bash Example

```bash
#!/bin/bash
query="$1"

cat <<EOF
{
  "items": [
    {
      "title": "Search GitHub for '$query'",
      "subtitle": "Open in browser",
      "arg": "https://github.com/search?q=$query",
      "icon": {"path": "icon.png"}
    }
  ]
}
EOF
```

### Python Example

```python
#!/usr/bin/env python3
import sys
import json

query = sys.argv[1] if len(sys.argv) > 1 else ""

results = {
    "items": [
        {
            "title": f"Search for {query}",
            "subtitle": "Press Enter to open",
            "arg": f"https://example.com/search?q={query}",
            "icon": {"path": "icon.png"}
        }
    ]
}

print(json.dumps(results))
```

### Node.js Example

```javascript
#!/usr/bin/env node
const query = process.argv[2] || "";

const results = {
  items: [
    {
      title: `Search for ${query}`,
      subtitle: "Press Enter to open",
      arg: `https://example.com/search?q=${query}`,
      icon: { path: "icon.png" }
    }
  ]
};

console.log(JSON.stringify(results));
```

## Actions

When a user selects an item, Summon performs an action based on the `arg` field:

- **URL** (starts with `http://`, `https://`, or custom scheme): Opens in default browser
- **File path** (starts with `/` or `~/`): Opens file
- **Command** (prefix with `cmd:`): Executes shell command
  - Example: `"arg": "cmd:open -a Safari"`

## Import/Export

Extensions can be packaged as `.summon` files (zip archives):

```bash
# Export
cd ~/Library/Application\ Support/Summon/extensions
zip -r my-extension.summon my-extension/

# Import
unzip my-extension.summon -d ~/Library/Application\ Support/Summon/extensions/
```

## Best Practices

1. **Performance**: Cache results when possible, use native tools (jq, rg, fd)
2. **Error handling**: Write errors to stderr, not stdout
3. **Debugging**: Use `echo "debug info" >&2` to debug without breaking JSON output
4. **Icons**: Use PNG files, 128x128 or 256x256 recommended
5. **Validation**: Test JSON output with `jq` before deploying

## Advanced Features

### Variables

Pass data between workflow steps using variables in the JSON:

```json
{
  "items": [...],
  "variables": {
    "workspace_name": "Development",
    "vault_path": "/Users/me/Vault"
  }
}
```

### Caching

Add cache hints to improve performance:

```json
{
  "items": [...],
  "cache": {
    "seconds": 300
  }
}
```

### Rerun

Auto-refresh results at intervals:

```json
{
  "items": [...],
  "rerun": 1.0
}
```
