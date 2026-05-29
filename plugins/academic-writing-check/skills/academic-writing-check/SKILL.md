---
name: academic-writing-check
description: >
  Check academic writing for common issues: overclaiming, rhetorical inflation,
  citation accuracy, formatting, terminology, and structural consistency. Use
  when reviewing drafts, before finalizing documents, or after significant edits.
---

# Academic Writing Review

Check the given document against 18 items in four groups. Report each violation with line/sentence reference and suggested correction. Do NOT make edits automatically; present findings first.

---

## Group 1: Rhetoric & Evidence Boundary

**1.1 Absolutism（绝对化）**
Words that assert exhaustiveness without supporting evidence:
全部, 所有, 均无, 无一, 从未, 唯一, 空白, 绝无, 完全, 彻底

**1.2 Inflation（过度拔高）**
Words that inflate significance without quantitative justification:
突破性, 开创性, 重大突破, 关键进展, 革命性, 颠覆性, 里程碑

**1.3 Rhetorical bloat（修辞膨胀）**
Empty intensifiers that add no information:
值得注意的是, 需要强调的是, 显而易见, 毋庸置疑, 众所周知, 不言而喻

**1.4 Subjective ranking（主观排序）**
Unsubstantiated ordinal or superlative claims:
最好, 最优, 第一, 首次, 领先, 最大, 最高, 最低（unless supported by cited quantitative comparison）

**1.5 Presumptive decision（替人决策）**
Imperative conclusions that exceed evidence scope:
必须, 应当, 势必, 将是, 必然, 理应（in descriptive/diagnostic contexts, not normative recommendations explicitly labeled as such）

**1.6 False causality（虚假归因）**
Causal language where only correlation is supported:
导致, 造成, 决定, 驱动, 症结, 根源, 本质, 根本原因

**1.7 Forced elevation（强行升华）**
Grandiose closing statements unsupported by preceding content:
具有划时代意义, 奠定了坚实基础, 做出了重要贡献, 为...提供了理论依据（when the connection is not demonstrated）

**1.8 Performative empathy（表演共情）**
Editorializing emotional expressions:
遗憾的是, 令人欣慰的是, 可喜的是, 不幸的是, 值得高兴的是

**1.9 Presumed stance（预设站队）**
Framing open academic debates as settled in a particular direction:
以公认的...、业界共识认为...、毫无疑问...（when the debate is ongoing）

**1.10 Fabricated precision（伪造精确）**
Quantitative claims without traceable source, or excessive significant digits implying unwarranted accuracy:
有效数字虚高, 未标注来源的百分比/倍数, 未经引用的具体数值

---

## Group 2: Citation & Format

**2.1 Citation accuracy（引述准确性）**
- Do cited numerical values match the original source?
- Are method names (e.g., POD-SVM, TD3) confirmed in the original paper?
- Is the journal name correct?
- Does the document accurately reflect the cited paper's conclusion (not exaggerated or distorted)?

**2.2 Citation context（引述语境）**
- Is the experimental condition (apparatus, scale, fuel type) preserved when generalizing findings?
- Is correlation presented as causation?
- Is method transferability (跨学科间距) acknowledged?

**2.3 Citation density（引述密度）**
- Does a single claim stack 3+ citations? Verify each citation independently supports the exact claim.
- Are multiple papers from the same research group treated as independent evidence?

**2.4 Formatting（格式规范）**
- Range indicators: `~` → `–` (en-dash)
- Super/subscript: Unicode chars → `<sup>` / `<sub>` tags
- Citation position: superscript at end of statement, not as sentence subject/object
- Encoding: UTF-8, LF line endings

---

## Group 3: Structure & Terminology

**3.1 Structural coherence（结构自洽）**
- Does the document invent structure not present in source documents (e.g., numbering sections that were continuous text)?
- Do section headings accurately reflect content?
- Does the summary introduce judgments not present in the body text?

**3.2 Terminology consistency（术语一致性）**
- Is the same concept referred to by different names across the document?
- Are abbreviations defined at first use?
- Are Chinese/English terms mixed inconsistently?

**3.3 Data presentation（数据呈现）**
- Do adjacent values use consistent significant digits?
- Is the baseline for percentage/multiple clearly stated (e.g., 提升至 1.59 倍 vs 提升了 1.59 倍)?
- Are units consistent throughout?

---

## Group 4: Language Naturalness

**4.1 Translationese（翻译腔）**
Word-for-word mapping from English that is grammatically correct but stylistically unnatural in Chinese academic writing. Common patterns:

| 翻译腔 | 自然表述 |
|---|---|
| X 路径中（numerical pathway） | X 方面 / X 方法 |
| 扮演...角色（play a role） | 起...作用 / 发挥...作用 |
| 一个...的方式（in a ... manner） | 以...方式 |
| 对...进行/开展研究（conduct research on） | 研究... |
| 在...背景下（in the context of） | 在...条件下 |
| 基于...的基础上（on the basis of） | 基于... |
| 具有...的性质（has the nature of） | 具有...特征 |
| 存在着...的问题（there exists the problem of） | 存在...问题 |

Principle: if removing a word still preserves meaning and reads more naturally, remove it. If a compound phrase maps one-to-one onto an English construction, consider whether a single Chinese word suffices.

When invoked, read the specified document and produce a report grouped by the three categories above. For each violation:

1. Quote the offending text (line reference)
2. Identify the specific issue (e.g., 1.1 绝对化)
3. Suggest a corrected version

Skip categories where no issues are found. Do not modify the document unless the user explicitly requests it.
