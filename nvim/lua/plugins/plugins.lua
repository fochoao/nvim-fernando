return {
  {
    "folke/neoconf.nvim",
  },

  -- add gruvbox
  { "ellisonleao/gruvbox.nvim" },

  -- change trouble config
  {
    "folke/trouble.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons"
    },
  },

  -- add symbols-outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = {
      {
        "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline"
      },
    },
    config = true,
  },

  -- add any tools you want to have installed below

  { "navarasu/onedark.nvim", priority = 1000 },

  { "nxstynate/oneDarkPro.nvim", priority = 1000 },

  { "preservim/nerdtree", priority = 1000 },

  { "aserebryakov/vim-todo-lists", priority = 1000 },

  { "rcarriga/nvim-dap-ui", requires = {"mfussenegger/nvim-dap"}, },

  { "nvim-dap-virtual-text", priority = 10000 },

  { "andrewferrier/debugprint.nvim", priority = 1000 },

  { "puremourning/vimspector" },

  { "lewis6991/gitsigns.nvim" },

  { "ggandor/lightspeed.nvim" },

  { "easymotion/vim-easymotion" },

  {
    'nvim-telescope/telescope.nvim', tag = '0.1.5',
    dependencies = {
      'nvim-lua/plenary.nvim'
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = { "Neotree" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      "s1n7ax/nvim-window-picker",
    },
    keys = {
      { "<C-F2>", "<cmd>Neotree filesystem toggle left<cr>", desc = "Neotree toggle filesystem" },
      { "<C-F3>", "<cmd>Neotree buffers toggle left<cr>", desc = "Neotree toggle buffers" },
      { "<C-F4>", "<cmd>Neotree git_status toggle left<cr>", desc = "Neotree toggle git status" },
    },
    config = function()
      local renderer = require("neo-tree.ui.renderer")

      -- Expand a node and load filesystem info if needed.
      local function open_dir(state, dir_node)
        local fs = require("neo-tree.sources.filesystem")
        fs.toggle_directory(state, dir_node, nil, true, false)
      end

      -- Expand a node and all its children, optionally stopping at max_depth.
      local function recursive_open(state, node, max_depth)
        local max_depth_reached = 1
        local stack = { node }
        while next(stack) ~= nil do
          node = table.remove(stack)
          if node.type == "directory" and not node:is_expanded() then
            open_dir(state, node)
          end

          local depth = node:get_depth()
          max_depth_reached = math.max(depth, max_depth_reached)

          if not max_depth or depth < max_depth - 1 then
            local children = state.tree:get_nodes(node:get_id())
            for _, v in ipairs(children) do
              table.insert(stack, v)
            end
          end
        end

        return max_depth_reached
      end

      --- Open the fold under the cursor, recursing if count is given.
      local function neotree_zo(state, open_all)
        local node = state.tree:get_node()

        if open_all then
          recursive_open(state, node)
        else
          recursive_open(state, node, node:get_depth() + vim.v.count1)
        end

        renderer.redraw(state)
      end

      --- Recursively open the current folder and all folders it contains.
      local function neotree_zO(state)
        neotree_zo(state, true)
      end

      -- The nodes inside the root folder are depth 2.
      local MIN_DEPTH = 2

      --- Close the node and its parents, optionally stopping at max_depth.
      local function recursive_close(state, node, max_depth)
        if max_depth == nil or max_depth <= MIN_DEPTH then
          max_depth = MIN_DEPTH
        end

        local last = node
        while node and node:get_depth() >= max_depth do
          if node:has_children() and node:is_expanded() then
            node:collapse()
          end
          last = node
          node = state.tree:get_node(node:get_parent_id())
        end

        return last
      end

      --- Close a folder, or a number of folders equal to count.
      local function neotree_zc(state, close_all)
        local node = state.tree:get_node()
        if not node then
          return
        end

        local max_depth
        if not close_all then
          max_depth = node:get_depth() - vim.v.count1
          if node:has_children() and node:is_expanded() then
            max_depth = max_depth + 1
          end
        end

        local last = recursive_close(state, node, max_depth)
        renderer.redraw(state)
        renderer.focus_node(state, last:get_id())
      end

      -- Close all containing folders back to the top level.
      local function neotree_zC(state)
        neotree_zc(state, true)
      end

      --- Open a closed folder or close an open one, with an optional count.
      local function neotree_za(state, toggle_all)
        local node = state.tree:get_node()
        if not node then
          return
        end

        if node.type == "directory" and not node:is_expanded() then
          neotree_zo(state, toggle_all)
        else
          neotree_zc(state, toggle_all)
        end
      end

      --- Recursively close an open folder or recursively open a closed folder.
      local function neotree_zA(state)
        neotree_za(state, true)
      end

      --- Set depthlevel, analagous to foldlevel, for the neo-tree file tree.
      local function set_depthlevel(state, depthlevel)
        if depthlevel < MIN_DEPTH then
          depthlevel = MIN_DEPTH
        end

        local stack = state.tree:get_nodes()
        while next(stack) ~= nil do
          local node = table.remove(stack)

          if node.type == "directory" then
            local should_be_open = depthlevel == nil or node:get_depth() < depthlevel
            if should_be_open and not node:is_expanded() then
              open_dir(state, node)
            elseif not should_be_open and node:is_expanded() then
              node:collapse()
            end
          end

          local children = state.tree:get_nodes(node:get_id())
          for _, v in ipairs(children) do
            table.insert(stack, v)
          end
        end

        vim.b.neotree_depthlevel = depthlevel
      end

      --- Refresh the tree UI after a change of depthlevel.
      -- @bool stay Keep the current node revealed and selected
      local function redraw_after_depthlevel_change(state, stay)
        local node = state.tree:get_node()

        if stay then
          require("neo-tree.ui.renderer").expand_to_node(state.tree, node)
        else
          -- Find the closest parent that is still visible.
          local parent = state.tree:get_node(node:get_parent_id())
          while not parent:is_expanded() and parent:get_depth() > 1 do
            node = parent
            parent = state.tree:get_node(node:get_parent_id())
          end
        end

        renderer.redraw(state)
        renderer.focus_node(state, node:get_id())
      end

      --- Update all open/closed folders by depthlevel, then reveal current node.
      local function neotree_zx(state)
        set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
        redraw_after_depthlevel_change(state, true)
      end

      --- Update all open/closed folders by depthlevel.
      local function neotree_zX(state)
        set_depthlevel(state, vim.b.neotree_depthlevel or MIN_DEPTH)
        redraw_after_depthlevel_change(state, false)
      end

      -- Collapse more folders: decrease depthlevel by 1 or count.
      local function neotree_zm(state)
        local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
        set_depthlevel(state, depthlevel - vim.v.count1)
        redraw_after_depthlevel_change(state, false)
      end

      -- Collapse all folders. Set depthlevel to MIN_DEPTH.
      local function neotree_zM(state)
        set_depthlevel(state, MIN_DEPTH)
        redraw_after_depthlevel_change(state, false)
      end

      -- Expand more folders: increase depthlevel by 1 or count.
      local function neotree_zr(state)
        local depthlevel = vim.b.neotree_depthlevel or MIN_DEPTH
        set_depthlevel(state, depthlevel + vim.v.count1)
        redraw_after_depthlevel_change(state, false)
      end

      -- Expand all folders. Set depthlevel to the deepest node level.
      local function neotree_zR(state)
        local top_level_nodes = state.tree:get_nodes()
        local max_depth = 1
        for _, node in ipairs(top_level_nodes) do
          max_depth = math.max(max_depth, recursive_open(state, node))
        end

        vim.b.neotree_depthlevel = max_depth
        redraw_after_depthlevel_change(state, false)
      end

      -- If you want icons for diagnostic errors, you'll need to define them somewhere:
      vim.fn.sign_define("DiagnosticSignError", { text = "❎", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DiagnosticSignWarn", { text = "⚠", texthl = "DiagnosticSignWarn" })
      vim.fn.sign_define("DiagnosticSignInfo", { text = "🚩", texthl = "DiagnosticSignInfo" })
      vim.fn.sign_define("DiagnosticSignHint", { text = "⛩", texthl = "DiagnosticSignHint" })

      require("neo-tree").setup({
        sources = {
          "filesystem",
          "buffers",
          "git_status",
        },
        close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
        popup_border_style = "rounded",
        enable_normal_mode_for_inputs = true, -- Enable normal mode for input dialogs.
        open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "edgy" },

        source_selector = {
          winbar = true, -- toggle to show selector on winbar
          statusline = true, -- toggle to show selector on statusline
          content_layout = "center", -- only with `tabs_layout` = "equal", "focus"
          separator = "", -- can be string or table, see below
        },
        default_component_configs = {
          git_status = {
            symbols = {
              -- Change type
              added = "✚", -- or "✚", but this is redundant info if you use git_status_colors on the name
              modified = "💠", -- or "", but this is redundant info if you use git_status_colors on the name
              deleted = "✖", -- this can only be used in the git_status source
              renamed = "❣", -- this can only be used in the git_status source
              -- Status type
              untracked = "🖲️",
              ignored = "⏭",
              unstaged = "🏤",
              staged = "🕴️",
              conflict = "⏺",
            },
          },
          symlink_target = {
            enabled = true,
          },
        },
        window = {
          width = 36,
          auto_expand_width = false,
          mappings = {
            ["<esc>"] = function()
              vim.cmd("nohl")
            end,
            ["<space>"] = "noop",
            ["<tab>"] = function(state)
              local node = state.tree:get_node()
              if require("neo-tree.utils").is_expandable(node) then
                state.commands["toggle_node"](state)
              else
                state.commands["open_with_window_picker"](state)
                vim.cmd("Neotree reveal")
              end
            end,
            -- ["o"] = "open_with_window_picker",
            ["t"] = "open_tabnew",
            ["s"] = "split_with_window_picker",
            ["v"] = "vsplit_with_window_picker",
            ["C"] = "close_node",
            ["a"] = {
              "add",
              -- some commands may take optional config options, see `:h neo-tree-mappings` for details
              config = {
                show_path = "absolute", -- "none", "relative", "absolute"
              },
            },
            ["h"] = "",
            ["l"] = "",

            ["z"] = "none",

            ["zo"] = neotree_zo,
            ["zO"] = neotree_zO,
            ["zc"] = neotree_zc,
            ["zC"] = neotree_zC,
            ["za"] = neotree_za,
            ["zA"] = neotree_zA,
            ["zx"] = neotree_zx,
            ["zX"] = neotree_zX,
            ["zm"] = neotree_zm,
            ["zM"] = neotree_zM,
            ["zr"] = neotree_zr,
            ["zR"] = neotree_zR,
            ["<m-h>"] = "none",
            ["<m-j>"] = "none",
            ["<m-k>"] = "none",
            ["<m-l>"] = "none",
          },
        },
        filesystem = {
          filtered_items = {
            visible = true, -- when true, they will just be displayed differently than normal items
            hide_dotfiles = true,
            hide_gitignored = false,
            hide_hidden = true, -- only works on Windows for hidden files/directories
            never_show = { -- remains hidden even if visible is toggled to true
              ".DS_Store",
              "thumbs.db",
            },
          },
          hijack_netrw_behavior = "disabled", -- netrw disabled, opening a directory opens neo-tree
          use_libuv_file_watcher = false, -- This will use the OS level file watchers to detect changes
          -- instead of relying on nvim autocmd events.
          window = {
            mappings = {
              ["i"] = "run_command",
              ["[c"] = "prev_git_modified",
              ["]c"] = "next_git_modified",
              ["gA"] = "git_add_all",
              ["gu"] = "git_unstage_file",
              ["ga"] = "git_add_file",
              ["gr"] = "git_revert_file",
              ["gc"] = "git_commit",
              ["gp"] = "git_push",
              ["gg"] = "git_commit_and_push",
              ["/"] = "none",
            },
          },
          commands = {
            run_command = function(state)
              local node = state.tree:get_node()
              local path = node:get_id()
              vim.api.nvim_input(": " .. path .. "<Home>")
            end,
          },
        },
        buffers = {
          follow_current_file = {
            enabled = false, -- This will find and focus the file in the active buffer every time
            --               -- the current file is changed while the tree is open.
            leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
          },
          -- time the current file is changed while the tree is open.
          group_empty_dirs = false, -- when true, empty folders will be grouped together
          show_unloaded = true,
          window = {
            mappings = {
              ["gA"] = "git_add_all",
              ["gu"] = "git_unstage_file",
              ["ga"] = "git_add_file",
              ["gr"] = "git_revert_file",
              ["gc"] = "git_commit",
              ["gp"] = "git_push",
              ["gg"] = "git_commit_and_push",
            },
          },
        },
        git_status = {
          window = {
            mappings = {
              ["A"] = "none",
              ["gA"] = "git_add_all",
            },
          },
        },
      })
      vim.g.neo_tree_remove_legacy_commands = 1
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
        delay = 0,
        ignore_whitespace = false,
      },
      sign_priority = 7,
      preview_config = {
        border = "rounded",
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]h", gs.next_hunk, "Next Hunk")
        map("n", "[h", gs.prev_hunk, "Prev Hunk")
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
        map("n", "<leader>ghb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>ghd", gs.diffthis, "Diff This")
        map("n", "<leader>ghD", function()
          gs.diffthis("~")
        end, "Diff This ~")
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      end,
      trouble = true,
    },
  },
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    cmd = {
      "GitConflictChooseOurs",
      "GitConflictChooseTheirs",
      "GitConflictChooseBoth",
      "GitConflictChooseNone",
      "GitConflictNextConflict",
      "GitConflictPrevConflict",
      "GitConflictListQf",
    },
    config = true,
  },

  {

    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    opts = {},
  },

  {
    'dinhhuy258/git.nvim'
  },

  {
    "lukas-reineke/headlines.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true, -- or `opts = {}`
  },

  {
    'saecki/crates.nvim',
    tag = 'stable',
    config = function()
        require('crates').setup()
    end,
  },

  {
    "udalov/kotlin-vim"
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
  },

  config = function()
    local lspconfig = require("lspconfig")
    local mason = require("mason")

    mason.setup()

    lspconfig.rust_analyzer.setup({})
    end,
  },

  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    }
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    },
  },

  { 
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter"
    },
  },
}