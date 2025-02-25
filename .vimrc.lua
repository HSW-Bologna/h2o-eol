--vim.api.nvim_create_autocmd("BufWritepost", {pattern = "*", callback = function ()
--vim.fn.system("python main.py")
--end})
local vim = vim

local overseer = require("overseer")
overseer.run_template({ name = "run script" }, function(task)
    if task then
        task:add_component({ "restart_on_save", paths = { vim.fn.expand("main.lua") } })
    else
        vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
    end
end)
