#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  CallToolRequestSchema,
  ListToolsRequestSchema
} from '@modelcontextprotocol/sdk/types.js'
import { zodToJsonSchema } from 'zod-to-json-schema'
import { tools } from './tools.js'

const server = new Server(
  { name: 'obsidian-vault', version: '0.1.0' },
  { capabilities: { tools: {} } }
)

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: Object.entries(tools).map(([name, tool]) => ({
    name,
    description: tool.description,
    inputSchema: zodToJsonSchema(tool.parameters) as Record<string, unknown>
  }))
}))

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params
  const tool = tools[name as keyof typeof tools]
  if (!tool) {
    throw new Error(`Unknown tool: ${name}`)
  }
  const result = await (tool.execute as (args: Record<string, unknown>) => Promise<unknown>)(args || {})
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(result, null, 2) }]
  }
})

async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
}

main().catch(console.error)
