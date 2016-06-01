--
-- Monitoring information obtained from the proc pseudo-file system
--
local procdata = {}

local unistd = require("posix.unistd")
local lfs = require("lfs")

--
-- Platform Information
--

-- OS, release, gcc version
local plat_file = "/proc/version"
local plat_patt = "([^%s]+)%s+version%s+([^%s]+)"
local gcc_patt = ".-gcc version ([%.%d]+)"
function procdata.get_platform()
  local fd = io.open(plat_file)
  if not fd then
    return nil, "Error opening "..plat_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local os, release = info:match(plat_patt)
  if not os then
    os = "unknown"
    release = "unknown"
  end
  local gcc = info:match(gcc_patt)
  if not gcc then
    gcc = "unknown"
  end
  return {os = os, release = release, gcc = gcc} 
end

--
-- Memory Information
--

local mem_fact = {k = 1024, m = 1024*1024, g = 1024*1024*1024}
local mem_patt = ":%s*(%d+)"
local unit_patt = ":%s*%d+%s*(%a+)"
local mem_file = "/proc/meminfo"
local ram_patt = "MemTotal"
local swap_patt = "SwapTotal"
local ramf_patt = "MemFree"
local swapf_patt = "SwapFree"

-- Convert memory info from provided unit to bytes
local function getm(info, type)
	local m = info:match(type..mem_patt)
  if not m then return nil end
  m = tonumber(m)
	local um = info:match(type..unit_patt)
  if not um then return m end
  local f = mem_fact[(um:sub(1,1)):lower()]
  if f then return m * f else return m end
end

-- Total memory (ram and swap) in bytes
function procdata.get_total_memory()
  local fd = io.open(mem_file)
  if not fd then
    return nil, "Error opening "..mem_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local ram = getm(info,ram_patt)
  if not ram then return nil, "Error getting ram" end
  local swap = getm(info,swap_patt)
  if not swap then return nil, "Error getting swap" end
  return {ram = ram, swap = swap} 
end

-- Free memory (ram and swap) in bytes
function procdata.get_free_memory()
  local fd = io.open(mem_file)
  if not fd then
    return nil, "Error opening "..mem_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local ram = getm(info,ramf_patt)
  if not ram then return nil, "Error getting free ram" end
  local swap = getm(info,swapf_patt)
  if not swap then return nil, "Error getting free swap" end
  return {ram = ram, swap = swap} 
end

-- Used memory (ram and swap) in bytes
function procdata.get_used_memory()
  local tmem, fmem, err
  tmem,err = procdata.get_total_memory()
  if not tmem then return nil, err end
  fmem, err = procdata.get_free_memory()
  if not fmem then return nil, err end
  return {ram = tmem.ram - fmem.ram, swap = tmem.swap - fmem.swap} 
end

--
-- CPU information
--

-- Number of cpus
local ncpus_file = "/proc/stat"
local ncpus_patt = "cpu%d+"
function procdata.get_num_cpus()
  local fd = io.open(ncpus_file)
  if not fd then
    return nil, "Error opening "..ncpus_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local ncpus = 0
  for _ in info:gmatch(ncpus_patt) do
    ncpus = ncpus + 1
  end
  if ncpus == 0 then 
    return 1
  else
    return ncpus
  end
end

-- Clock speed (in MHz)
local speed_alt1_file = "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
local speed_alt2_file = "/proc/cpuinfo"
local speed_alt2_patt = "cpu MHz%s*:%s*(%d+)"

function procdata.get_clock_speed()
  local fd, info, cspeed
  -- first we try /sys
  fd = io.open(speed_alt1_file)
  if fd then
    cspeed = tonumber(fd:read("*a"))/1000
    io.close(fd)
  else
    -- alternatively we try /proc/cpuinfo to get highest speed
    fd = io.open(speed_alt2_file)
    if not fd then
      return nil, 
        "Cannot find either ..speed_alt1_file".. "or "..speed_alt2_file
    end
    info = fd:read("*a")
    io.close(fd)
    cspeed = 0
    for sp in info:gmatch(speed_alt2_patt) do
      sp = tonumber(sp)
      if sp > cspeed then
        cspeed = sp
      end
    end
    if cspeed == 0 then
      return nil, "Error getting cpu clock speed"
    end
  end
  return cspeed
end

-- Load average (loadavg, runnable/total scheduling entities)
local lavg_file = "/proc/loadavg"
local lavg_patt = "(%d+%.%d+)%s+(%d+%.%d+)%s+(%d+%.%d+)"
local ent_patt = "%d+%.%d+%s+%d+%.%d+%s+%d+%.%d+%s+(%d+)/(%d+)"

function procdata.get_cpu_load()
  local fd = io.open(lavg_file)
  if not fd then
    return nil, "Error opening "..lavg_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local l1,l5,l15 = info:match(lavg_patt)
  if not l1 then
    return nil, "Error getting load average"
  end
  local t = {l1 = tonumber(l1), l5 = tonumber(l5), l15 = tonumber(l15)}
  local re,te = info:match(ent_patt)
  if re then
    t.runnable = tonumber(re)
    t.total = tonumber(te)
  end
  return t
end

-- CPU times (user, nice, system, idle) in seconds
local ctimes_file = "/proc/stat"
local ctimes_patt = "cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)"

function procdata.get_cpu_times()
  local fd = io.open(ctimes_file)
  if not fd then
    return nil, "Error opening "..ctimes_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local usr,nice,sys,idle = info:match(ctimes_patt)
  if not usr then
    return nil, "Error getting cpu times"
  end
  local cticks = unistd.sysconf(unistd._SC_CLK_TCK)
  return {user = tonumber(usr)/cticks,
          nice = tonumber(nice)/cticks, 
          system = tonumber(sys)/cticks,
          idle = tonumber(idle)/cticks}
end

-- System uptime in seconds
local uptime_file = "/proc/uptime"
function procdata.get_uptime()
  local fd = io.open(uptime_file)
  if not fd then
    return nil, "Error opening "..uptime_file
  end
  local info = fd:read("*a")
  io.close(fd)
  local upt = info:match("(%d+%.%d+)")
  if not upt then
    return nil, "Error getting system uptime"
  end
  return upt
end

--
-- Processes information
--

-- pid, ppid, command string, state 
-- user and system time (in seconds)
-- starttime (in seconds since standard epoch)
-- memory use: virtual, resident and shared (in bytes)
local skip = string.rep("[^%s]*%s+",9)
local stat_patt = "%s*(%d+)%s+%(([^)]+)%)%s+(%a)%s+(%d+)%s+"..skip..
                  "(%d+)%s+(%d+)"
local statm_patt = "%s*(%d+)%s+(%d+)%s+(%d+)"

function procdata.get_process_info(pid)
  if not pid then
    return nil, "Process ID (pid) not provided"
  end
  local fproc = "/proc/"..pid
  local fstat = fproc.."/stat"
  local fstatm = fproc.."/statm"

  local fd = io.open(fstat)
  if not fd then
    return nil, "Process "..pid.." not found"
  end
  local info = fd:read("*a")
  io.close(fd)
  local pid,comm,state,ppid,utime,stime = 
        info:match(stat_patt)
  if not pid then
    return nil, "Error getting process "..pid.." info"
  end
  local cticks = unistd.sysconf(unistd._SC_CLK_TCK)
  utime = tonumber(utime)/cticks
  stime = tonumber(stime)/cticks

  local starttime
  local attr,err = lfs.attributes(fproc)
  if not attr then
    starttime = 0
  else
    starttime = attr.change
  end

  fd = io.open(fstatm)
  local vmsize, rss, shared
  if fd then
    info = fd:read("*a")
    io.close(fd)
    vmsize,rss,shared = info:match(statm_patt)
    local psize = 4096
    if not vmsize then 
      vmsize = 0
      rss = 0
      shared = 0
    else
      vmsize = tonumber(vmsize) * psize
      rss = tonumber(rss) * psize
      shared = tonumber(shared) * psize
    end
  end

  local t =  {
          pid = tonumber(pid), ppid = tonumber(ppid),
          comm = comm, state = state,
          utime = utime, stime = stime, starttime = starttime,
          vmsize = vmsize, rss = rss, shared = shared,
  }
  t.walltime = os.time() - t.starttime
  return t
end

-- get all processes
function procdata.get_processes()
  local pids = {}
  for dir in lfs.dir("/proc") do
    if tonumber(dir) then
      table.insert(pids,tonumber(dir))
    end
  end
  return pids
end

-- get process children
local ppid_patt = "%s*%d+%s+%([^)]+%)%s+%a%s+(%d+).*"
function procdata.get_children(pid)
  if not pid then
    return nil, "Process ID (pid) not provided"
  end
  local children = {}
  local pids = procdata.get_processes()
  for i = 1, #pids do
    local child = pids[i]
    local file_pid =  "/proc/"..child.."/stat"
    local fd = io.open(file_pid)
    if fd then
      local info = fd:read("*a")
      io.close(fd)
      local ppid = info:match(ppid_patt)
      if tonumber(ppid) == pid then
        table.insert(children, child)
      end
    end
  end
  return children
end

return procdata
