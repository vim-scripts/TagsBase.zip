syn match TagsBaseLine /^\d\+/
syn match TagsBaseType /\%(^\d\+\s\+\)\@<=\S\+/
syn match TagsBaseName /\%(^\d\+\s\+\S\+\)\@<=.*/

highlight def link TagsBaseLine Number
highlight def link TagsBaseType Keyword
highlight def link TagsBaseName Identifier
