# IMBUS Project Documentation

**Project:** Implementing More and Better Use of ICES Survey Data  
**Call:** EMFAF-2025-PIA-FisheriesScientificAdvice · Proposal 101241455  
**Duration:** Sep 2025 – Aug 2027

This is the documentation Quarto website project for IMBUS WP2.
The technical R package implementation lives in the parallel [`obus`](../obus) project.

## Structure

```
imbus/
  deliverables/      WP2 formal deliverables (D2.2, ...)
  background/        Project overview, user requirements summary
  meetings/          Meeting minutes converted from .docx
  reference.docx     Word template for docx output
  _quarto.yml        Quarto website configuration
```

## Rendering

```bash
# Render the full website (HTML)
quarto render

# Render a single document to Word (for Sharepoint upload)
quarto render deliverables/D2.2_data_formats_metadata.qmd --to docx

# Preview locally
quarto preview
```

## Word template

`reference.docx` is a Quarto default Word template. To customise styles (fonts, heading colours,
margins), open it in Word, modify the styles, save, and re-render.
