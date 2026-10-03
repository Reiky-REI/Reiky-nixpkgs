import { z } from 'zod'
import {
  readJournal, createPage, searchVault, addBacklink,
  listPages, buildIndex, readPage, appendToPage, getVaultPath, listJournals
} from './vault.js'

export const tools = {
  read_journal: {
    description: '读取指定日期的日记内容，不传日期则读今天',
    parameters: z.object({
      date: z.string().optional().describe('日期，格式 YYYY_MM_DD，如 2026_06_01')
    }),
    execute: async (args: { date?: string }) => {
      const content = await readJournal(args.date)
      return { content, date: args.date || '今天' }
    }
  },

  create_page: {
    description: '新建笔记页面，如果已存在则提示',
    parameters: z.object({
      title: z.string().describe('页面标题'),
      content: z.string().describe('页面内容（Markdown 格式）')
    }),
    execute: async (args: { title: string; content: string }) => {
      const result = await createPage(args.title, args.content)
      return { result }
    }
  },

  append_to_page: {
    description: '向已有页面追加内容，不存在则创建',
    parameters: z.object({
      title: z.string().describe('页面标题'),
      content: z.string().describe('要追加的内容（Markdown 格式）')
    }),
    execute: async (args: { title: string; content: string }) => {
      const result = await appendToPage(args.title, args.content)
      return { result }
    }
  },

  search_vault: {
    description: '全文搜索笔记库中的内容',
    parameters: z.object({
      query: z.string().describe('搜索关键词')
    }),
    execute: async (args: { query: string }) => {
      const results = await searchVault(args.query)
      return { results }
    }
  },

  read_page: {
    description: '读取指定页面的内容',
    parameters: z.object({
      title: z.string().describe('页面标题')
    }),
    execute: async (args: { title: string }) => {
      const content = await readPage(args.title)
      return { title: args.title, content }
    }
  },

  add_backlink: {
    description: '在两个笔记页面之间添加双向链接 [[目标]]',
    parameters: z.object({
      source: z.string().describe('源页面标题'),
      target: z.string().describe('目标页面标题'),
      context: z.string().optional().describe('链接上下文说明，如"相关知识点"')
    }),
    execute: async (args: { source: string; target: string; context?: string }) => {
      const result = await addBacklink(args.source, args.target, args.context)
      const reverseResult = await addBacklink(args.target, args.source, args.context)
      return { result, reverseLink: reverseResult }
    }
  },

  list_pages: {
    description: '列出所有笔记页面，可按标签筛选',
    parameters: z.object({
      tag: z.string().optional().describe('标签关键词筛选')
    }),
    execute: async (args: { tag?: string }) => {
      const pages = await listPages(args.tag)
      return { pages, total: pages.length }
    }
  },

  list_journals: {
    description: '列出所有日记文件',
    parameters: z.object({}),
    execute: async () => {
      const journals = await listJournals()
      return { journals, total: journals.length }
    }
  },

  build_index: {
    description: '为主题生成笔记索引页',
    parameters: z.object({
      topic: z.string().describe('主题名称'),
      pages: z.array(z.string()).describe('要包含的页面标题列表')
    }),
    execute: async (args: { topic: string; pages: string[] }) => {
      const result = await buildIndex(args.topic, args.pages)
      return { result }
    }
  },

  vault_info: {
    description: '查看笔记库的基本信息',
    parameters: z.object({}),
    execute: async () => {
      const vaultPath = getVaultPath()
      const pages = await listPages()
      const journals = await listJournals()
      return { vaultPath, totalPages: pages.length, totalJournals: journals.length, pages, journals }
    }
  }
} as const
