# procdata
Lua access to system information provided by the Linux _**/proc**_ pseudo-file system.

## Dependencies

- luaposix
- luafilesystem

## API

### Notes: ###

- When a function returns a table, the table keys are **boldfaced**.
- All functions return _nil_ and an error message in case of error.

**procdata.get_platform()**

Obtains platform information from _/proc/version_. Returns a table containing the **os** type and **release**, and the **gcc** version.

**procdata.get_total_memory()**

Obtains the total amount of memory, from _/proc/meminfo_. Returns a table containing the total amount of **ram** and **swap** memory in bytes.

**procdata.get_free_memory()**

Obtains the amount of free memory, from _/proc/meminfo_. Returns a table containing the amount of free **ram** and **swap** memory in bytes.

**procdata.get_used_memory()**

Obtains the amount of used memory, from _/proc/meminfo_. Returns a table containing the amount of used **ram** and **swap** memory in bytes.

**procdata.get_num_cpus()**

Obtains the number of cpus, from _/proc/stat_.

**procdata.get_clock_speed()**

Obtains the maximum frequency available for the system's processors (in MHz).

In order to get a more accurate value, it may use _cpuinfo_max_freq_, which resides in the cpufreq directory in the _/sys/devices_ hierarchy. If this resource is not availavble, _/proc/avcpuinfo_ is used.

**procdata.get_cpu_load()**

Obtains current load average numbers, from _/proc/loadavg_. Returns a table containing the number of queued runnable jobs, averaged over 1 (**l1**), 5 (**l5**) and 15 (**l15**) minutes. When available, returns also the **total** number of scheduling entities (processes, threads) and the number of currently **executing** entities.

**procdata.get_cpu_times()**

Obtains the amount of time (in seconds) that the system spent in different modes, from _/proc/stat_. Returns a table containg the time spent in **user** mode, user mode with low priority (**nice**), **system** mode and the **idle** task.

**procdata.get_uptime()**

Obtains the uptime of the system (in seconds) from _/proc/uptime_.

**procdata.get_process_info(pid)**

Obtains information for a running process, given its process ID (pid). This information is gathered from _/proc/[pid]/stat_ and _/proc/[pid]/statm_. Returns a table containing:
- the process's **pid**
- its parent's processid (**ppid**)
- the filename of its executable (**comm**)
- the process's current **state**, specified by one character from "RSDZTW", for running (R), sleeping but interruptible (S), waiting for disk and uninterruptible (D), zombie (Z), traced or stopped on a signal (T) and paging (W).
- the amount of time (in seconds) the process has been scheduled in user (**utime**) and system (**stime**) mode
- the process's **starttime**, given in seconds since standard epoch
- memory used by the process (in bytes): total (**vmsize**), resident (**rss**) and **shared**
 
Note: Because the process's startime provided by  _/proc/[pid]/stat_ cannot always be trusted, this function uses  the pseudo-directory  _/proc/[pid]/_ creation time, obtained with LuaFileSystem.


**procdata.get_processes()**

Returns a table (an _array_) containing the process IDs for all running processes in the system.

This function uses LuaFileSystem to obtain all numerical subdirectories under _/proc/_.

**procdata.get_children(pid)**

Returns a table (an _array_) containing the process IDs for all the immediate children of a process, given its process ID (pid).







