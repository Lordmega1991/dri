---
description: Design System Pattern - Modern Minimalist Forms
---

# Modern Minimalist Form Pattern (DRI Standard)

This pattern is established as the project standard for forms, focusing on high readability, rounded aesthetics (2rem), and professional slate/indigo tones.

## Core Layout Structure

```tsx
<div className="min-h-screen bg-white text-slate-700 font-sans">
  {/* Sticky Header */}
  <header className="bg-white border-b border-slate-100 sticky top-0 z-40">
    <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
      <div className="flex items-center gap-4">
        {/* Navigation / Back Button */}
        <Link href="..." className="p-2 hover:bg-slate-50 rounded-full text-slate-400">
           <ArrowLeft size={18} />
        </Link>
        <h1 className="text-lg font-bold text-slate-800 tracking-tight italic">Page Title</h1>
      </div>
      {/* Primary Action Button (Header) */}
      <button className="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-full font-bold text-sm shadow-lg shadow-indigo-100">
        Save
      </button>
    </div>
  </header>

  <main className="max-w-5xl mx-auto px-6 py-10">
    <form className="space-y-10">
       {/* Section */}
       <section className="space-y-6">
          <div className="flex items-center gap-2 text-indigo-600">
             <Icon size={16} />
             <h2 className="text-[10px] font-black uppercase tracking-[2px]">Section Title</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
             {/* Form Group */}
             <div className="relative">
                <InputIcon className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                <input 
                   className="w-full bg-white border border-slate-200 rounded-[2rem] py-4 pl-14 pr-5 text-sm font-bold text-slate-700 outline-none focus:border-indigo-500 transition-all uppercase"
                   placeholder="Placeholder..."
                />
             </div>
          </div>
       </section>
    </form>
  </main>
</div>
```

## CSS Tokens & Classes

- **Background**: `bg-white` (Main), `bg-slate-50` (Secondary/Contrast)
- **Borders**: `border-slate-100` (Light), `border-slate-200` (Input default)
- **Radius**: `rounded-[2rem]` (Fields & Cards), `rounded-full` (Buttons)
- **Text**: 
  - Section Labels: `text-[10px] font-black uppercase tracking-[2px]`
  - Input Text: `text-sm font-bold text-slate-700`
  - Headers: `italic font-bold tracking-tight`
- **Colors**:
  - Indigo-600: Primary Action / Section Icons
  - Slate-900: Finalize/Secondary Action
  - Emerald-50/600: Success / Credentials Banners

## Guidelines

1. **Icons**: Every section and major input should have a Luide-React icon for visual anchoring.
2. **Uppercase**: Input text values and section titles are typically forced to `uppercase` or `font-bold` for a technical, assertive look.
3. **Spacing**: Use `space-y-10` between main sections and `space-y-6` within sections.
4. **Padding**: Inputs must have generous left padding (`pl-14`) to accommodate absolute positioned icons.
