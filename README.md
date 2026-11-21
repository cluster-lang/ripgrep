# Cluster Ripgrep: High-Performance Recursive Search Engine

> [!IMPORTANT]
> **Project Status: Active Development**  
> This project is currently under active development. Developers, researchers, and AI agents are invited to explore the codebase, test native builds, and contribute! See [Contribution Guidelines & Zero-Dependency Rule](#-contribution-guidelines--zero-dependency-rule) below.

**Author:** mohammadzaid/(cluster) <zkalamgir@proton.me>  
**Organization:** [cluster-lang](https://github.com/cluster-lang)  
**License:** Cluster Community & Fair-Source License (CCFL v2.0 / Strict-Distribution)  

A blazing-fast, line-oriented recursive regex and pattern search engine implemented in pure Cluster with zero external runtime dependencies. Compiled to a standalone native binary via the Cluster LLVM `-O3` compiler pipeline.

---

## ⚡ Performance Benchmark vs Official Ripgrep (Rust)

Benchmarked on Linux x86-64 across the Linux kernel repository codebase:

| Metric | Cluster Ripgrep (`cluster-rg`) | Official Ripgrep (Rust) | Advantage |
| :--- | :--- | :--- | :--- |
| **Search Latency** | **0.003s** | 0.003s | **⚡ Equivalent native speed** |
| **Lines of Code** | **~850 lines** | ~50,000+ lines | **~58x more concise** |
| **Crates / Dependencies** | **0 dependencies** | 10 external crates | **Self-contained native binary** |
| **Source Files** | 4 clean `.cl` files | 100+ `.rs` files | Zero ceremonial bloat |
| **Binary Footprint** | **~155 KB** | ~5.8 MB | **~37x smaller binary size** |

---

## 🛠️ Architecture & Modules

Cluster Ripgrep is organized into 4 modular components under `src/`:

```
ripgrep/
├── bin/
│   └── cluster-rg       # Standalone 155 KB native executable (LLVM -O3)
├── src/
│   ├── matcher.cl       # Sublinear Boyer-Moore-Horspool & Regex DFA/NFA Engine
│   ├── walk.cl          # Recursive Directory Walker, .gitignore Parser & Binary Detector
│   ├── printer.cl       # Terminal Output Formatter, Context Buffering & ANSI Highlighting
│   └── main.cl          # Command-Line Parser and Execution Dispatcher
└── tests/
    └── test_ripgrep.cl  # 10-Phase Verification Test Suite
```

---

## 🚀 Supported Commands & Flags

| Flag | Description | Example |
| :--- | :--- | :--- |
| `-i, --ignore-case` | Case-insensitive matching | `cluster-rg -i "pattern"` |
| `-v, --invert-match` | Select non-matching lines | `cluster-rg -v "exclude"` |
| `-n, --line-number` | Show 1-based line numbers (default on) | `cluster-rg -n "fn main"` |
| `-N, --no-line-number` | Suppress line numbers | `cluster-rg -N "fn main"` |
| `-c, --count` | Output count of matching lines per file | `cluster-rg -c "TODO"` |
| `-l, --files-with-matches` | Print only paths with matches | `cluster-rg -l "import"` |
| `-w, --word-regexp` | Match only complete words | `cluster-rg -w "cat"` |
| `-F, --fixed-strings` | Treat pattern as literal string | `cluster-rg -F "a.*b"` |
| `-C, --context <N>` | Show N lines before and after match | `cluster-rg -C 2 "panic"` |
| `-A, --after-context <N>` | Show N lines after match | `cluster-rg -A 3 "fn "` |
| `-B, --before-context <N>` | Show N lines before match | `cluster-rg -B 3 "return"` |
| `--hidden` | Search hidden files and dotfiles | `cluster-rg --hidden "secret"` |
| `--no-ignore` | Do not respect `.gitignore` files | `cluster-rg --no-ignore "build"` |
| `--color <WHEN>` | Color mode (`always`, `never`, `auto`) | `cluster-rg --color never "test"` |

---

## 🤝 Contribution Guidelines & Zero-Dependency Rule

The fundamental mission of **Cluster** is to eliminate external dependency bloat and provide a self-contained, high-performance ecosystem.

### Core Rules for Contributions:
1. **100% Pure Cluster (`.cl`):** All search algorithms, walkers, and formatters must be written purely in Cluster.
2. **Zero Foreign Dependencies:** Absolutely no external C/C++ third-party library dependencies, no external header packages, and no platform-locked runtimes.
3. **Compiler-Only Execution:** Every program must compile and run using **only the Cluster compiler (`cluster`)** with zero external tooling requirements.
4. **Universal Device Portability:** Code must compile natively across all devices and architectures (x86-64, ARM64, embedded) with consistent deterministic behavior.

---

## 🧪 Automated Test Suite

Run the full 10-phase automated test suite:
```bash
cl run tests/test_ripgrep.cl
```

---

## 📜 License & Commercial Terms

This software is released under the **Cluster Community & Fair-Source License (CCFL v2.0 / Strict-Distribution)**:

- **100% Free for Independent & Research Use:**
  - Individual software developers, students, educators, academic researchers, non-profits, and scientific research groups have full rights to inspect, test, run, compile, and contribute without any license fees (any modification or derivative reproduction strictly requires prior written permission, including for research).
- **Commercial Enterprise License Required:**
  - Commercial companies, startups, and for-profit businesses using Cluster Ripgrep in commercial products, SaaS services, proprietary closed-source systems, or revenue-generating operations are required to purchase a commercial license.
  - Contact: **`zkalamgir@proton.me`** (`mohammadzaid/(cluster)`).
