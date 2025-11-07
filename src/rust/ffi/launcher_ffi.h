#ifndef LAUNCHER_FFI_H
#define LAUNCHER_FFI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SearchEngineHandle SearchEngineHandle;

typedef struct {
  char *id;
  char *name;
  char *path;
  int64_t score;
} CSearchResult;

#define ITEM_TYPE_APPLICATION 0
#define ITEM_TYPE_FILE 1
#define ITEM_TYPE_SNIPPET 2
#define ITEM_TYPE_CLIPBOARD_ENTRY 3

SearchEngineHandle *search_engine_new(void);
void search_engine_free(SearchEngineHandle *handle);

bool search_engine_add_item(SearchEngineHandle *handle, const char *id,
                            const char *name, const char *path,
                            int32_t item_type);

// Returns array owned by caller. Free with search_results_free
CSearchResult *search_engine_search(SearchEngineHandle *handle,
                                    const char *query, size_t limit,
                                    size_t *out_count);

void search_results_free(CSearchResult *results, size_t count);

bool search_engine_stats(SearchEngineHandle *handle, size_t *total,
                         size_t *apps, size_t *files, size_t *snippets);

typedef struct SnippetMatcherHandle SnippetMatcherHandle;

typedef struct {
  char *trigger;
  char *content;
  size_t match_end;
} CSnippetMatch;

SnippetMatcherHandle *snippet_matcher_new(void);
void snippet_matcher_free(SnippetMatcherHandle *handle);

bool snippet_matcher_update(SnippetMatcherHandle *handle, const char *json);

// Returns match owned by caller. Free with snippet_match_free
CSnippetMatch *snippet_matcher_find(SnippetMatcherHandle *handle,
                                    const char *text);

void snippet_match_free(CSnippetMatch *result);

typedef struct FontCacheHandle FontCacheHandle;

FontCacheHandle *font_cache_new(void);
void font_cache_free(FontCacheHandle *handle);

bool font_cache_initialize(FontCacheHandle *handle, const char *json);
bool font_cache_is_initialized(FontCacheHandle *handle);

// Returns string owned by caller. Free with font_cache_free_string
char *font_cache_get_families_json(FontCacheHandle *handle);
char *font_cache_get_fonts_for_family_json(FontCacheHandle *handle,
                                           const char *family);

void font_cache_free_string(char *s);

typedef struct CalculatorHandle CalculatorHandle;

CalculatorHandle *calculator_new(void);
void calculator_free(CalculatorHandle *handle);

// Returns string owned by caller. Free with calculator_free_string
char *calculator_evaluate(CalculatorHandle *handle, const char *query);

void calculator_free_string(char *s);

// Returns string owned by caller. Free with calculator_free_string
char *calculator_get_history_json(CalculatorHandle *handle);
void calculator_clear_history(CalculatorHandle *handle);

// ============================================================================
// Clipboard Storage
// ============================================================================

typedef struct ClipboardStorageHandle ClipboardStorageHandle;

typedef struct {
  char *content;
  double timestamp;
  uint8_t item_type;
  char *image_file_path;
  double image_width;
  double image_height;
  int32_t size;
  char *source_app;
} CClipboardEntry;

#define CLIPBOARD_TYPE_TEXT 0
#define CLIPBOARD_TYPE_IMAGE 1
#define CLIPBOARD_TYPE_UNKNOWN 2

ClipboardStorageHandle *clipboard_storage_new(const char *path);
void clipboard_storage_free(ClipboardStorageHandle *handle);

bool clipboard_storage_add_text(ClipboardStorageHandle *handle,
                                const char *content, double timestamp,
                                int32_t size, const char *source_app);

bool clipboard_storage_add_image(ClipboardStorageHandle *handle,
                                 const char *content, double timestamp,
                                 const char *image_file_path, double width,
                                 double height, int32_t size,
                                 const char *source_app);

// Returns array owned by caller. Free with clipboard_entries_free
CClipboardEntry *clipboard_storage_get_entries(ClipboardStorageHandle *handle,
                                               size_t start, size_t count,
                                               size_t *out_count);

size_t clipboard_storage_len(ClipboardStorageHandle *handle);
bool clipboard_storage_trim(ClipboardStorageHandle *handle, size_t max_entries);
bool clipboard_storage_clear(ClipboardStorageHandle *handle);

void clipboard_entries_free(CClipboardEntry *entries, size_t count);

// ============================================================================
// Snippet Storage
// ============================================================================

typedef struct SnippetStorageHandle SnippetStorageHandle;

typedef struct {
  char *id;
  char *trigger;
  char *content;
  bool enabled;
  char *category;
} CSnippet;

SnippetStorageHandle *snippet_storage_new(const char *path);
void snippet_storage_free(SnippetStorageHandle *handle);

bool snippet_storage_add(SnippetStorageHandle *handle, const char *id,
                         const char *trigger, const char *content, bool enabled,
                         const char *category);

bool snippet_storage_update(SnippetStorageHandle *handle, const char *id,
                            const char *trigger, const char *content,
                            bool enabled, const char *category);

bool snippet_storage_delete(SnippetStorageHandle *handle, const char *id);

// Returns array owned by caller. Free with snippets_free
CSnippet *snippet_storage_get_all(SnippetStorageHandle *handle,
                                  size_t *out_count);
CSnippet *snippet_storage_get_enabled(SnippetStorageHandle *handle,
                                      size_t *out_count);

size_t snippet_storage_len(SnippetStorageHandle *handle);

void snippets_free(CSnippet *snippets, size_t count);

#ifdef __cplusplus
}
#endif

#endif
