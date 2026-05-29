# Intensive Reading — Annotation Rules

## Five Markers

| Marker | Purpose |
|--------|---------|
| `▶ 理论补充` | Prerequisite theory — background knowledge needed before reading the passage |
| `▷ 解析` | Paragraph analysis: what it claims, how it connects, why it matters |
| `◆ 关键概念` | First occurrence of a domain-specific term — one-sentence definition |
| `※ 注意` | Pitfall, limitation, hidden assumption, common misunderstanding |
| `→ 延伸` | Related work, alternative approach, further reading |

`▷` is mandatory per paragraph — the workhorse. `◆`/`※`/`→` may be appended within the same blockquote when the analysis naturally calls for them, each on its own `>` line. One blockquote per paragraph, not multiple.

`◆ 关键概念` fires once per term (first occurrence only).

`▶ 理论补充` goes in the prerequisites section (prepend.md), NOT inline in the body. In the body, reference it: "(see Prerequisite Theory: LSTM)".

## Annotation Length (Chinese sentences)

| Marker | Length | Rationale |
|--------|--------|-----------|
| `▶ 理论补充` | 5–12 sentences | Primers need enough depth to build understanding from undergraduate STEM baseline |
| `▷ 解析` | 3–8 sentences | Explain what, why, how it connects — not just restate |
| `◆ 关键概念` | 1–2 sentences | Definition only; deeper explanation belongs in primer or `▷` |
| `※ 注意` | 1–4 sentences | One caveat per marker; split multiple caveats into separate `※` blocks |
| `→ 延伸` | 2–5 sentences | Point to the right reference and why it matters |

Guidelines, not hard limits. Equations can push `▷` longer when every term needs interpretation. Dense paragraphs may warrant longer analysis.

## Per-Paragraph Output Format

```
[Original paragraph text.]

[Chinese translation in plain text, no blockquote.]

> ▷ 解析：[paragraph analysis]
> ◆ 关键概念：[term definition, first occurrence only]
> ※ 注意：[caveat if applicable]
> → 延伸：[extension if applicable]
```

Translation goes directly after the original paragraph. Annotation blockquote goes after the translation.

**Visual distinction:** Annotations must be visually separable from original text. Use blockquote formatting (`> ▷ ...`) for paragraph-level annotations. Translations are plain text (no blockquote) to distinguish them from annotations. For block-level annotations (primer sections, appendix content), use section headings to separate.

## Language Rules

- Annotations and translations are always in Chinese, regardless of the paper's language. Original text stays in its language.
- Appendix C (Glossary) maps English terms to Chinese.
- Translations must use the Chinese terms assigned in `_survey.md` — do NOT invent new ones.

**Translation format:** Chinese translations are placed directly after the original paragraph, in plain text without any blockquote marker. Translations should be faithful to the original meaning, preserve technical terms as-is per the loanword rules below, and match the tone of the original (academic, not colloquial).

**English terms to preserve untranslated:** Keep common technical loanwords in their English form when they are the dominant usage in Chinese academic discourse. Do NOT translate these to rare or awkward Chinese equivalents. The table below is illustrative and non-exhaustive — the rule of thumb at the bottom takes precedence over the table:

| Keep as English | Do NOT translate to |
|-----------------|---------------------|
| prompt | 提示词 |
| token | 词元 |
| embedding | 嵌入向量（可混用，但首次出现标注英文） |
| fine-tuning | 微调（可混用） |
| benchmark | 基准（可混用） |
| overfitting | 过拟合（可混用） |
| dropout | (保留英文) |
| batch size | (保留英文) |
| pipeline | 流水线（可混用） |
| API | (保留英文) |
| plugin | 插件（可混用） |
| server | 服务器（可混用） |

Rule of thumb: if the English word appears untranslated in mainstream Chinese technical media (e.g., 知乎, 机器之心, CSDN), keep it. If a natural Chinese equivalent is widely used and not awkward (e.g., 神经网络 for neural network, 梯度下降 for gradient descent), use the Chinese. When uncertain, keep the English and add a Chinese gloss in parentheses on first use.

## Equation Annotation

For every numbered equation, insert a `▷ 解析` explaining: physical meaning of each term, why this specific form (empirical? first-principles?), what happens at limits, whether exact or approximate. No numbered equation may be skipped.

Example:
```
∂h̄_i/∂t = (h_i·ṁ_i − h_{i−1}·ṁ_{i−1} + Q̇ + V_i·dp/dt − h̄_i·V_i·dρ̄/dt) / M_i  (2)

> ▷ 式 (2) 能量守恒（瞬态形式）：
> - h_i·ṁ_i − h_{i−1}·ṁ_{i−1}：净焓流入（对流项）
> - Q̇：通过管壁的传热量（源项，散热为负值）
> - V_i·dp/dt：流动功（压力变化对能量的贡献）
> - −h̄_i·V_i·dρ̄/dt：密度变化导致的能量变化
> - M_i：控制体内蒸汽总质量（分母，将总能量变化率转化为比焓变化率）
> - 适用范围：单相或均相两相流，控制体内物性均匀假设
```

## Figure/Table Annotation

For every figure/table caption: translation is mandatory, `▷ 解析` is optional. The visual content itself is not annotated.

## Paragraph Definition

A paragraph is the smallest annotation unit. Boundaries are determined by structure, not by natural-language intuition:

- Text blocks separated by blank lines or headings are distinct paragraphs.
- Ordered/unordered lists are treated as a single paragraph (do not annotate each item separately).
- Figure and table captions are separate paragraphs (translation mandatory, `▷ 解析` optional). The figure or table body itself is not a paragraph — do not attempt to translate or annotate it.
- A standalone equation (set off by blank lines, on its own line or lines) is a separate paragraph. No Chinese translation is needed; a `▷ 解析` annotation is mandatory.
- An inline equation embedded within a text paragraph belongs to that paragraph — translate and annotate together.

## Coverage

- Every body paragraph: translation + `▷ 解析` — mandatory. Standalone equations: `▷ 解析` only.
- Every numbered equation: `▷ 解析` — mandatory
- Every figure/table caption: translation mandatory, `▷ 解析` optional. The visual content itself is not translated or annotated.

## Annotation Writing Guidance

After each paragraph: `▷ 解析` explains what the paragraph claims, how it connects to preceding argument, what is assumed vs. demonstrated, why it matters to the paper's overall argument.

After each equation: `▷ 解析` explains physical meaning of each term, why this specific form was chosen, what happens at limits, whether the relationship is exact or approximate.

After each figure/table caption (optional): `▷ 解析` may explain what to look for in the data, what patterns would confirm or challenge the paper's claims, how to read the axes, units, and error bars.

## Handling Missing or Ambiguous Content

Flag gaps with `※ 注意` rather than guessing. Template:

> ※ 注意：文中未明确给出 [X] 的定义/取值，疑似 [合理推测]，需对照参考文献或联系作者确认。
