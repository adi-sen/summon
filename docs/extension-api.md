# Summon Extension API Documentation

## Extension System

Summon supports script filter extensions that can be written in any language and shared between users.

### Script Filter Extensions
- Located in `~/Library/Application Support/Summon/extensions/`
- Written in any language (Bash, Python, Node.js, etc.)
- Can be shared via export/import (`.summonext` files)
- Typical performance: 20-100ms per query

## Script Filter Extension Structure

Each extension is a directory in `~/Library/Application Support/Summon/extensions/` containing:

```
my-extension/
├── manifest.json    # Extension metadata
├── script.sh        # Your executable script
├── icon.png         # (Optional) Custom icon
└── README.md        # (Optional) Documentation
```

## Manifest Format

`manifest.json` defines your extension's metadata:

```json
{
  "name": "My Extension",
  "description": "What this extension does",
  "author": "Your Name",
  "version": "1.0.0",
  "keyword": "myext",
  "script": "script.sh",
  "icon": "icon.png"
}
```

### Fields

- **name** (required): Display name shown in settings
- **description** (required): Brief description of functionality
- **author** (required): Extension author name
- **version** (required): Semantic version (e.g., "1.0.0")
- **keyword** (required): Trigger keyword to activate extension
- **script** (required): Executable script filename
- **icon** (optional): SF Symbol name or path to custom icon file

## Script Protocol

### Input

Your script receives the user's query as the first argument:

```bash
#!/usr/bin/env bash
query="$1"
```

### Output

Scripts must output JSON to stdout in this format:

```json
{
  "items": [
    {
      "title": "Result Title",
      "subtitle": "Additional information",
      "arg": "https://example.com",
      "icon": {"path": "icon.png"},
      "valid": true,
      "uid": "unique-id"
    }
  ]
}
```

### Item Fields

- **title** (required): Main text displayed
- **subtitle** (optional): Secondary text below title
- **arg** (optional): Action to perform when selected:
  - URLs: `https://example.com` - Opens in browser
  - Files: `/path/to/file` - Opens file
  - Commands: `cmd:echo hello` - Executes shell command
  - If omitted, copies title to clipboard
- **icon** (optional): Object with `path` to icon file
- **valid** (optional): Set to `false` to disable selection (default: `true`)
- **uid** (optional): Unique identifier for caching
- **quicklook** (optional): URL for Quick Look preview

## Performance Guidelines

### Caching

- Results are cached for 2 seconds per query
- Cache size: 100 entries (LRU eviction)
- Use consistent UIDs for better caching

### Timeouts

- Scripts must complete within 2000ms
- Optimize for fast execution (< 500ms recommended)
- Use background processing for slow operations

### Best Practices

1. **Fast Startup**: Keep script initialization minimal
2. **Incremental Results**: Return partial results quickly
3. **Error Handling**: Catch errors and return user-friendly messages
4. **Idempotent**: Same query should return consistent results
5. **Resource Limits**: Avoid excessive memory/CPU usage

## Examples

### Basic Search

```bash
#!/usr/bin/env bash
query="$1"

results=$(find ~/Documents -name "*$query*" -maxdepth 2 -type f | head -5)

echo '{"items":['
first=true
while IFS= read -r file; do
    [ "$first" = true ] && first=false || echo ","
    basename=$(basename "$file")
    echo "  {\"title\":\"$basename\",\"subtitle\":\"$file\",\"arg\":\"$file\"}"
done <<< "$results"
echo ']}'
```

### API Query (Python)

```python
#!/usr/bin/env python3
import sys
import json
import requests

query = sys.argv[1] if len(sys.argv) > 1 else ""

response = requests.get(f"https://api.example.com/search?q={query}")
data = response.json()

items = [
    {
        "title": item["name"],
        "subtitle": item["description"],
        "arg": item["url"]
    }
    for item in data.get("results", [])
]

print(json.dumps({"items": items}))
```

### Calculator

```javascript
#!/usr/bin/env node
const expr = process.argv[2] || '';

if (!expr) {
    console.log(JSON.stringify({
        items: [{
            title: "Enter an expression",
            subtitle: "e.g., 2 + 2",
            valid: false
        }]
    }));
} else {
    try {
        const result = eval(expr);
        console.log(JSON.stringify({
            items: [{
                title: String(result),
                subtitle: `${expr} = ${result}`,
                arg: String(result)
            }]
        }));
    } catch (e) {
        console.log(JSON.stringify({
            items: [{
                title: "Invalid expression",
                subtitle: e.message,
                valid: false
            }]
        }));
    }
}
```

## Action Types

### Open URL
```json
{"arg": "https://google.com"}
```

### Open File
```json
{"arg": "/Users/you/Documents/file.pdf"}
```

### Run Command
```json
{"arg": "cmd:osascript -e 'display notification \"Hello\"'"}
```

### Copy to Clipboard
```json
{"title": "Text to copy"}
```
*Omit `arg` to copy title to clipboard*

## Testing Extensions

Use the built-in extension tester:
1. Open Settings → Extensions
2. Click on your extension
3. Click "Test Extension"
4. Enter test queries and verify output

## Debugging

### Check Script Execution

```bash
cd ~/Library/Application\ Support/Summon/extensions/your-extension
./script.sh "test query"
```

### Common Issues

1. **Script not executing**: Check file permissions (`chmod +x script.sh`)
2. **Invalid JSON**: Validate output with `jq`
3. **Timeout errors**: Optimize slow operations or increase cache
4. **No results**: Verify script outputs to stdout (not stderr)

## Language Support

Summon supports any executable script:

- **Bash**: `#!/usr/bin/env bash`
- **Python**: `#!/usr/bin/env python3`
- **Node.js**: `#!/usr/bin/env node`
- **Ruby**: `#!/usr/bin/env ruby`
- **AppleScript**: `#!/usr/bin/osascript`
- **Swift**: Compile to binary
- **Rust**: Compile to binary

## Distribution

### Sharing Extensions

Use Summon's built-in export/import:

1. **Export**: Extension info → "Export" button → saves as `.summonext` file
2. **Share**: Send the `.summonext` file
3. **Import**: Extensions tab → "Import" button → select file
4. Summon automatically loads the extension

The `.summonext` file is a zip archive with your extension directory.

## API Changes

This API is stable. Breaking changes will be versioned and documented.

**Current Version**: 1.0.0
