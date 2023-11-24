" show line numbers
set number

" show at least 5 lines above/below the cursor when scrolling
set scrolloff=5

" ignore case when searching
set ignorecase

" set tabs equal to 4 spaces
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4

" convert existing tabs to spaces when running nvim
autocmd FileType * retab
