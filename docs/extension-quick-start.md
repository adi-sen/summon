# Extension Quick Start Guide

## Create Your First Extension in 3 Minutes

### Option 1: Use the Built-in Creator (Recommended)

1. Open Summon Settings → Extensions
2. Click "Create Extension"
3. Fill in the form:
   - Name: "My First Extension"
   - Keyword: "test"
   - Description: "A test extension"
   - Select template: "Search/Filter"
   - Select language: "Bash"
4. Click "Create Extension"
5. The script will open automatically - customize it!

### Option 2: Manual Creation

```bash
# Create extension directory
cd ~/Library/Application\ Support/Summon/extensions
mkdir my-extension
cd my-extension

# Create manifest
cat > manifest.json <<'EOF'
{
  "name": "My Extension",
  "description": "Does something cool",
  "author": "Me",
  "version": "1.0.0",
  "keyword": "test",
  "script": "script.sh"
}
EOF

# Create script
cat > script.sh <<'EOF'
#!/usr/bin/env bash
query="$1"

echo "{\"items\":[{\"title\":\"Hello $query\",\"subtitle\":\"You searched for $query\"}]}"
EOF

# Make executable
chmod +x script.sh

# Test it
./script.sh "world"
```

## Quick Templates

### File Searcher
```bash
#!/usr/bin/env bash
query="$1"

echo '{"items":['
first=true
while IFS= read -r file; do
    [ "$first" = true ] && first=false || echo ","
    basename=$(basename "$file")
    echo "  {\"title\":\"$basename\",\"subtitle\":\"$file\",\"arg\":\"$file\"}"
done < <(find ~/Documents -name "*$query*" -type f 2>/dev/null | head -10)
echo ']}'
```

### Text Transformer
```python
#!/usr/bin/env python3
import sys, json

text = sys.argv[1] if len(sys.argv) > 1 else ""

items = [
    {"title": text.upper(), "subtitle": "Uppercase", "arg": text.upper()},
    {"title": text.lower(), "subtitle": "Lowercase", "arg": text.lower()},
    {"title": text.title(), "subtitle": "Title Case", "arg": text.title()},
]

print(json.dumps({"items": items}))
```

### Web API Query
```javascript
#!/usr/bin/env node
const query = process.argv[2] || '';

// Simulated API response
const items = [
    {
        title: `Result for "${query}"`,
        subtitle: "Click to open",
        arg: `https://example.com/search?q=${encodeURIComponent(query)}`
    }
];

console.log(JSON.stringify({ items }));
```

## Testing Your Extension

### Built-in Tester
1. Settings → Extensions → Your Extension
2. Click "Test Extension"
3. Enter test queries
4. View JSON output and execution time

### Command Line
```bash
cd ~/Library/Application\ Support/Summon/extensions/my-extension
./script.sh "test query"
```

### Validate JSON
```bash
./script.sh "test" | jq .
```

## Common Patterns

### Empty Query Handling
```bash
if [ -z "$query" ]; then
    echo '{"items":[{"title":"Type to search","valid":false}]}'
    exit 0
fi
```

### Error Handling
```python
try:
    result = do_something(query)
    items = [{"title": result}]
except Exception as e:
    items = [{"title": "Error", "subtitle": str(e), "valid": false}]

print(json.dumps({"items": items}))
```

### Multiple Results
```bash
results=("Result 1" "Result 2" "Result 3")

echo '{"items":['
for i in "${!results[@]}"; do
    [ $i -gt 0 ] && echo ","
    echo "  {\"title\":\"${results[$i]}\",\"arg\":\"${results[$i]}\"}"
done
echo ']}'
```

## Icon Options

### SF Symbols
```json
"icon": "star.fill"
```

### Custom Image
```json
"icon": "custom-icon.png"
```
Place `custom-icon.png` in your extension directory.

## Next Steps

- Read the [full API documentation](extension-api.md)
- Check example extensions in the extensions gallery
- Join the community to share your extensions
- Optimize for performance (< 500ms execution time)

## Troubleshooting

**Extension not showing up?**
- Restart Summon
- Check manifest.json is valid JSON
- Verify script has execute permissions

**No results appearing?**
- Test script directly: `./script.sh "test"`
- Validate JSON output with `jq`
- Check stderr for errors

**Timeout errors?**
- Optimize slow operations
- Use caching for repeated queries
- Keep execution under 2 seconds

## Resources

- API Documentation: `docs/extension-api.md`
- Example Extensions: `~/Library/Application Support/Summon/extensions/`
- Community: [GitHub Discussions](https://github.com)
