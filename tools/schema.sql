-- Schéma SQLite du dictionnaire français (hors ligne)
-- Contenu issu du Wiktionnaire : licence CC BY-SA 4.0
-- Les ajouts personnels ont source = 'perso' (non soumis à la clause SA)

PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
PRAGMA foreign_keys = ON;

CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE entries (
    id         INTEGER PRIMARY KEY,
    word       TEXT NOT NULL,              -- forme affichée : « être »
    norm       TEXT NOT NULL,              -- forme normalisée : « etre »
    pos        TEXT,                       -- catégorie : nom, verbe, adj...
    gender     TEXT,                       -- m, f, mf ou NULL
    ipa        TEXT,                       -- prononciation (API)
    etymology  TEXT,
    is_lemma   INTEGER NOT NULL DEFAULT 1, -- 0 = forme fléchie seule
    freq       INTEGER NOT NULL DEFAULT 0, -- popularité pour l'autocomplétion
    source     TEXT NOT NULL DEFAULT 'wiktionnaire',
    source_url TEXT                        -- page d'origine (attribution)
);
CREATE INDEX idx_entries_norm ON entries(norm);
CREATE INDEX idx_entries_word ON entries(word);

CREATE TABLE senses (
    id         INTEGER PRIMARY KEY,
    entry_id   INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    ord        INTEGER NOT NULL,
    definition TEXT NOT NULL,
    register   TEXT,                       -- familier, soutenu, vieilli...
    domain     TEXT                        -- droit, religion, botanique...
);
CREATE INDEX idx_senses_entry ON senses(entry_id, ord);

CREATE TABLE examples (
    id       INTEGER PRIMARY KEY,
    sense_id INTEGER NOT NULL REFERENCES senses(id) ON DELETE CASCADE,
    text     TEXT NOT NULL
);
CREATE INDEX idx_examples_sense ON examples(sense_id);

CREATE TABLE relations (
    entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    type     TEXT NOT NULL CHECK (type IN ('synonyme','antonyme','derive','expression')),
    word     TEXT NOT NULL
);
CREATE INDEX idx_relations_entry ON relations(entry_id, type);

-- « mangeons » -> manger ; « belles » -> beau
-- `form` n'est renseigné que s'il diffère de `norm` (accents, majuscules) :
-- on économise ainsi un tiers de la place.
CREATE TABLE forms (
    norm     TEXT NOT NULL,
    entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    form     TEXT,
    PRIMARY KEY (norm, entry_id)
) WITHOUT ROWID;

-- Recherche instantanée : préfixes + mots, sans accents ni casse
CREATE VIRTUAL TABLE search_fts USING fts5(
    word,
    norm,
    content = 'entries',
    content_rowid = 'id',
    prefix = '2 3 4',
    tokenize = 'unicode61 remove_diacritics 2'
);
