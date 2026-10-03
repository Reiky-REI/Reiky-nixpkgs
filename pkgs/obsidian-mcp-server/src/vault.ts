import { readFile, writeFile, readdir, appendFile } from 'fs/promises'
import { existsSync } from 'fs'
import path from 'path'

const VAULT_PATH = process.env.VAULT_PATH || path.join(process.env.HOME || '', 'WorkSpace', 'notes')

export function getVaultPath(): string {
  return VAULT_PATH
}

export async function readJournal(date?: string): Promise<string> {
  const dateStr = date || today()
  const journalPath = path.join(VAULT_PATH, 'journals', `${dateStr}.md`)
  try {
    return await readFile(journalPath, 'utf-8')
  } catch {
    return '（今天还没有日记）'
  }
}

export async function createPage(title: string, content: string): Promise<string> {
  const pagePath = path.join(VAULT_PATH, 'pages', `${title}.md`)
  if (existsSync(pagePath)) {
    return `页面 ${title} 已存在，如需追加请使用 append_to_page`
  }
  await writeFile(pagePath, content, 'utf-8')
  return `已创建 pages/${title}.md`
}

export async function appendToPage(title: string, content: string): Promise<string> {
  const pagePath = path.join(VAULT_PATH, 'pages', `${title}.md`)
  try {
    await appendFile(pagePath, '\n' + content, 'utf-8')
    return `已追加到 pages/${title}.md`
  } catch {
    await writeFile(pagePath, content, 'utf-8')
    return `已创建 pages/${title}.md`
  }
}

export async function readPage(title: string): Promise<string> {
  const pagePath = path.join(VAULT_PATH, 'pages', `${title}.md`)
  try {
    return await readFile(pagePath, 'utf-8')
  } catch {
    return `页面 ${title} 不存在`
  }
}

export interface SearchResult {
  file: string
  snippet: string
}

export async function searchVault(query: string): Promise<SearchResult[]> {
  const results: SearchResult[] = []
  for (const dir of ['journals', 'pages']) {
    const dirPath = path.join(VAULT_PATH, dir)
    try {
      const files = await readdir(dirPath)
      for (const file of files) {
        if (!file.endsWith('.md')) continue
        const content = await readFile(path.join(dirPath, file), 'utf-8')
        if (content.includes(query)) {
          const lines = content.split('\n')
          const snippet = lines.find(l => l.includes(query))?.trim() || ''
          results.push({ file: `${dir}/${file}`, snippet })
        }
      }
    } catch {
      continue
    }
  }
  return results
}

export async function addBacklink(source: string, target: string, context?: string): Promise<string> {
  const sourcePath = path.join(VAULT_PATH, 'pages', `${source}.md`)
  try {
    let content = await readFile(sourcePath, 'utf-8')
    const link = `[[${target}]]`
    if (content.includes(link)) {
      return `页面 ${source} 已有指向 ${target} 的链接`
    }
    const appending = context
      ? `\n- ${context}：${link}`
      : `\n- 相关：${link}`
    await appendFile(sourcePath, appending, 'utf-8')
    return `已在 ${source} 中添加 [[${target}]]`
  } catch {
    return `页面 ${source} 不存在`
  }
}

export async function listPages(tag?: string): Promise<string[]> {
  const pagesPath = path.join(VAULT_PATH, 'pages')
  try {
    let files = await readdir(pagesPath)
    let pages = files.filter(f => f.endsWith('.md')).map(f => f.replace(/\.md$/, ''))
    if (tag) {
      const filtered: string[] = []
      for (const p of pages) {
        const content = await readFile(path.join(pagesPath, `${p}.md`), 'utf-8')
        if (content.includes(tag)) filtered.push(p)
      }
      return filtered
    }
    return pages
  } catch {
    return []
  }
}

export async function buildIndex(topic: string, pageList: string[]): Promise<string> {
  const lines = [
    `- # ${topic}`,
    `- 标签:: [[${topic}]]`,
    '',
    '## 笔记索引',
    ...pageList.map(p => `- [[${p}]]`),
  ]
  return await createPage(`${topic}-笔记索引`, lines.join('\n'))
}

export async function listJournals(): Promise<string[]> {
  const journalsPath = path.join(VAULT_PATH, 'journals')
  try {
    const files = await readdir(journalsPath)
    return files.filter(f => f.endsWith('.md')).map(f => f.replace(/\.md$/, ''))
  } catch {
    return []
  }
}

function today(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = `${d.getMonth() + 1}`.padStart(2, '0')
  const day = `${d.getDate()}`.padStart(2, '0')
  return `${y}_${m}_${day}`
}
