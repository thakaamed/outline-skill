#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Resolve outline.sh — lives inside the skill directory
const OUTLINE_SH = resolve(__dirname, "..", "skills", "outline", "scripts", "outline.sh");

/**
 * Execute an outline.sh command and return its stdout.
 * Passes OUTLINE_API_KEY and OUTLINE_API_URL from environment.
 */
function runOutline(
  command: string,
  args: string[] = [],
  stdin?: string
): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = execFile(
      "bash",
      [OUTLINE_SH, command, ...args],
      {
        env: {
          ...process.env,
          OUTLINE_API_KEY: process.env.OUTLINE_API_KEY ?? "",
          OUTLINE_API_URL: process.env.OUTLINE_API_URL ?? "",
        },
        maxBuffer: 10 * 1024 * 1024, // 10MB for large documents
        timeout: 30000,
      },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr || error.message));
        } else {
          resolve(stdout);
        }
      }
    );

    if (stdin && child.stdin) {
      child.stdin.write(stdin);
      child.stdin.end();
    }
  });
}

/** Helper to return MCP text content */
function text(content: string) {
  return { content: [{ type: "text" as const, text: content }] };
}

// ─── Create Server ────────────────────────────────────────────────────

const server = new McpServer({
  name: "outline",
  version: "1.0.0",
});

// ─── Tools ────────────────────────────────────────────────────────────

// SEARCH
server.tool(
  "outline_search",
  "Full-text search across all documents in the Outline wiki. Returns document IDs, titles, URLs, and context snippets.",
  {
    query: z.string().describe("Search query string"),
    limit: z
      .number()
      .min(1)
      .max(100)
      .default(10)
      .describe("Maximum number of results (default 10)"),
  },
  async ({ query, limit }) => text(await runOutline("search", [query, String(limit)]))
);

// SEARCH TITLES
server.tool(
  "outline_search_titles",
  "Search document titles only (faster, no content matching). Returns IDs, titles, and last-updated dates.",
  {
    query: z.string().describe("Title search query"),
    limit: z.number().min(1).max(100).default(10).describe("Max results"),
  },
  async ({ query, limit }) =>
    text(await runOutline("search-titles", [query, String(limit)]))
);

// GET DOCUMENT
server.tool(
  "outline_get_document",
  "Retrieve the full markdown content of a document by its ID.",
  {
    document_id: z.string().describe("Outline document ID"),
  },
  async ({ document_id }) => text(await runOutline("get", [document_id]))
);

// DOCUMENT INFO
server.tool(
  "outline_document_info",
  "Get metadata about a document (title, ID, revision, dates, collection, parent, URL).",
  {
    document_id: z.string().describe("Outline document ID"),
  },
  async ({ document_id }) => text(await runOutline("info", [document_id]))
);

// LIST DOCUMENTS
server.tool(
  "outline_list_documents",
  "List documents, optionally filtered by collection ID. Returns up to 25 docs with IDs, titles, and dates.",
  {
    collection_id: z
      .string()
      .optional()
      .describe("Optional collection ID to filter by"),
  },
  async ({ collection_id }) =>
    text(await runOutline("list", collection_id ? [collection_id] : []))
);

// LIST COLLECTIONS
server.tool(
  "outline_collections",
  "List all collections (top-level folders) in the Outline wiki.",
  {},
  async () => text(await runOutline("collections"))
);

// CHILDREN
server.tool(
  "outline_children",
  "List child documents nested under a parent document.",
  {
    parent_id: z.string().describe("Parent document ID"),
  },
  async ({ parent_id }) => text(await runOutline("children", [parent_id]))
);

// DRAFTS
server.tool(
  "outline_drafts",
  "List unpublished draft documents.",
  {
    limit: z.number().min(1).max(100).default(25).describe("Max results"),
  },
  async ({ limit }) => text(await runOutline("drafts", [String(limit)]))
);

// COLLECTION TREE
server.tool(
  "outline_collection_tree",
  "Get the full nested document tree for a collection.",
  {
    collection_id: z.string().describe("Collection ID"),
  },
  async ({ collection_id }) =>
    text(await runOutline("collection-tree", [collection_id]))
);

// CREATE DOCUMENT
server.tool(
  "outline_create_document",
  "Create a new document in the Outline wiki. Provide title, collection ID, and markdown content.",
  {
    title: z.string().describe("Document title"),
    collection_id: z.string().describe("Collection ID to create the document in"),
    content: z.string().describe("Markdown content for the document body"),
  },
  async ({ title, collection_id, content }) =>
    text(await runOutline("create", [title, collection_id], content))
);

// UPDATE DOCUMENT
server.tool(
  "outline_update_document",
  "Update an existing document's title and/or content.",
  {
    document_id: z.string().describe("Document ID to update"),
    title: z.string().describe("New document title"),
    content: z.string().describe("New markdown content"),
  },
  async ({ document_id, title, content }) =>
    text(await runOutline("update", [document_id, title], content))
);

// MOVE DOCUMENT
server.tool(
  "outline_move_document",
  "Move a document under a new parent document.",
  {
    document_id: z.string().describe("Document ID to move"),
    parent_id: z.string().describe("New parent document ID"),
  },
  async ({ document_id, parent_id }) =>
    text(await runOutline("move", [document_id, parent_id]))
);

// ARCHIVE DOCUMENT
server.tool(
  "outline_archive_document",
  "Archive a document (soft delete, recoverable).",
  {
    document_id: z.string().describe("Document ID to archive"),
  },
  async ({ document_id }) =>
    text(await runOutline("archive", [document_id]))
);

// DELETE DOCUMENT
server.tool(
  "outline_delete_document",
  "Delete a document. By default moves to trash; use permanent=true for permanent deletion.",
  {
    document_id: z.string().describe("Document ID to delete"),
    permanent: z
      .boolean()
      .default(false)
      .describe("If true, permanently delete (cannot be recovered)"),
  },
  async ({ document_id, permanent }) =>
    text(
      await runOutline(
        "delete",
        permanent ? [document_id, "--permanent"] : [document_id]
      )
    )
);

// VERSION HISTORY
server.tool(
  "outline_version_history",
  "Show the version table embedded in a document (document-level changelog).",
  {
    document_id: z.string().describe("Document ID"),
  },
  async ({ document_id }) =>
    text(await runOutline("version-history", [document_id]))
);

// VERSION INIT
server.tool(
  "outline_version_init",
  "Add a version table (v1.0.0) to a document that does not have one yet.",
  {
    document_id: z.string().describe("Document ID"),
    author: z.string().describe("Author name for the initial version entry"),
  },
  async ({ document_id, author }) =>
    text(await runOutline("version-init", [document_id, author]))
);

// VERSION BUMP
server.tool(
  "outline_version_bump",
  "Bump the version of a document (major/minor/patch) and record a change summary in the version table.",
  {
    document_id: z.string().describe("Document ID"),
    bump_type: z
      .enum(["major", "minor", "patch"])
      .describe("Version bump type: major (breaking), minor (new content), patch (typos/fixes)"),
    summary: z.string().describe("Human-readable summary of changes in this version"),
    author: z.string().describe("Author name"),
  },
  async ({ document_id, bump_type, summary, author }) =>
    text(
      await runOutline("version-bump", [
        document_id,
        bump_type,
        summary,
        author,
      ])
    )
);

// ─── Start Server ─────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Outline MCP Server v1.0.0 running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
