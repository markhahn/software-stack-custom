help([[Nixpkgs is a collection of packages for the Nix package manager - Homepage: https://github.com/NixOS/nixpkgs]])
whatis("Description: Nixpkgs is a collection of packages for the Nix package manager - Homepage: https://github.com/NixOS/nixpkgs")

add_property(   "lmod", "sticky")

require("SitePackage")

local root = "/cvmfs/soft.computecanada.ca/nix/var/nix/profiles/16.09"
local cc_cluster = os.getenv("CC_CLUSTER") or "computecanada"
local arch = os.getenv("RSNT_ARCH") or ""
local interconnect = os.getenv("RSNT_INTERCONNECT") or ""

if not arch or arch == "" then
	if cc_cluster == "cedar" or cc_cluster == "graham" then
		arch = "avx2"
	else
		arch = get_highest_supported_architecture()
	end
end
if not interconnect or interconnect == "" then
	if cc_cluster == "cedar" then
		interconnect = "omnipath"
	else
		interconnect = get_interconnect()
	end
end

setenv("NIXUSER_PROFILE", root)
prepend_path("PATH", pathJoin(root, "sbin"))
prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("PATH", "/cvmfs/soft.computecanada.ca/custom/bin")
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("C_INCLUDE_PATH", pathJoin(root, "include"))
prepend_path("CPLUS_INCLUDE_PATH", pathJoin(root, "include"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("ACLOCAL_PATH", pathJoin(root, "share/aclocal"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "share/pkgconfig"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
setenv("FONTCONFIG_FILE", pathJoin(root, "etc/fonts/fonts.conf"))
prepend_path("PYTHONPATH", "/cvmfs/soft.computecanada.ca/custom/python/site-packages")
setenv("PERL5OPT", "-I" .. pathJoin(root, "lib/perl5") .. " -I" .. pathJoin(root, "lib/perl5/site_perl"))
prepend_path("PERL5LIB", pathJoin(root, "lib/perl5/site_perl"))
prepend_path("PERL5LIB", pathJoin(root, "lib/perl5"))
setenv("TZDIR", pathJoin(root,"share/zoneinfo"))
setenv("SSL_CERT_FILE", "/etc/pki/tls/certs/ca-bundle.crt")
setenv("CURL_CA_BUNDLE", "/etc/pki/tls/certs/ca-bundle.crt")
setenv("PAGER", "less -R")
pushenv("LESSOPEN", "|" .. pathJoin(root, "bin/lesspipe.sh %s"))
setenv("LOCALE_ARCHIVE", pathJoin(root, "lib/locale/locale-archive"))
if os.getenv("XDG_DATA_DIRS") then
	prepend_path("XDG_DATA_DIRS", pathJoin(root, "share"))
else
	setenv("XDG_DATA_DIRS", pathJoin(root, "share") .. ":/usr/local/share:/usr/share")
end
if os.getenv("XDG_CONFIG_DIRS") then
	prepend_path("XDG_CONFIG_DIRS", pathJoin(root, "etc/xdg"))
else
	setenv("XDG_CONFIG_DIRS", pathJoin(root, "etc/xdg") .. ":/etc/xdg")
end

-- silence harmless MXM warnings from libmxm
setenv("MXM_LOG_LEVEL", "error")

require("os")
-- Define RSNT variables
-- do something only at load time, if not already defined. Otherwise, unloading the module will lose the predefined value if there is one
if mode() == "load" then
	setenv("RSNT_ARCH", arch)
end
if mode() == "load" then
	setenv("RSNT_INTERCONNECT", interconnect)
end
if os.getenv("SLURM_TMPDIR") and (not os.getenv("TMPDIR") or os.getenv("TMPDIR") == "/tmp") then
	setenv("TMPDIR", os.getenv("SLURM_TMPDIR"))
end

-- let pip use our wheel house
if arch == "avx512" then
        setenv("PIP_CONFIG_FILE", "/cvmfs/soft.computecanada.ca/config/python/pip-avx512.conf")
elseif arch == "avx2" then
        setenv("PIP_CONFIG_FILE", "/cvmfs/soft.computecanada.ca/config/python/pip-avx2.conf")
elseif arch == "avx" then
        setenv("PIP_CONFIG_FILE", "/cvmfs/soft.computecanada.ca/config/python/pip-avx.conf")
else
        setenv("PIP_CONFIG_FILE", "/cvmfs/soft.computecanada.ca/config/python/pip.conf")
end

-- also make easybuild and easybuild-generated modules accessible
prepend_path("PATH", "/cvmfs/soft.computecanada.ca/easybuild/bin")
setenv("EASYBUILD_CONFIGFILES", "/cvmfs/soft.computecanada.ca/easybuild/config.cfg")
setenv("EASYBUILD_BUILDPATH", pathJoin("/dev/shm", os.getenv("USER")))

setenv("EBROOTNIXPKGS", root)
setenv("EBVERSIONNIXPKGS", "16.09")

prepend_path("MODULEPATH", "/cvmfs/soft.computecanada.ca/easybuild/modules/2017/Core")

local user = os.getenv("USER","unknown")
local home = os.getenv("HOME",pathJoin("/home",user))
if user ~= "ebuser" then
    prepend_path("MODULEPATH", pathJoin(home, ".local/easybuild/modules/2017/Core"))
end

-- define PROJECT and SCRATCH environments
local posix = require("posix")
local stat = posix.stat

local def_scratch_dir = pathJoin("/scratch",user)
local def_project_link = pathJoin(home,"project")
local project_dir = nil

-- if project_dir was not found based on SLURM_JOB_ACCOUNT, test the default project 
project_dir = def_project_link
if not project_dir and stat(def_project_link,"type") == "link" then
	-- find the directory this link points to
	project_dir = subprocess("readlink " .. def_project_link)
end
if project_dir and (stat(project_dir,"type") == "link" or stat(project_dir, "type") == "dir") then
	-- if PROJECT is not defined, or if it was defined by us previously (i.e. in the login environment), define it
	if not os.getenv("PROJECT") or os.getenv("PROJECT") == os.getenv("CC_PROJECT") then
		setenv("PROJECT", project_dir)
	end
	-- define CC_PROJECT nevertheless
	setenv("CC_PROJECT", project_dir)
end
-- do not overwrite the environment variable if it already exists
if not os.getenv("SCRATCH") then
--	if stat(def_scratch_dir,"type") == "directory" then
		setenv("SCRATCH", def_scratch_dir)
--	end
end

-- if SLURM_TMPDIR is set, define TMPDIR to use it unless TMPDIR was already set to something different than /tmp
if os.getenv("SLURM_TMPDIR") and (not os.getenv("TMPDIR") or os.getenv("TMPDIR") == "/tmp") then
	setenv("TMPDIR", os.getenv("SLURM_TMPDIR"))
	setenv("LOCAL_SCRATCH", os.getenv("SLURM_TMPDIR"))
end


-- if SQUEUE_FORMAT is not already defined, define it
if not os.getenv("SQUEUE_FORMAT") then
	setenv("SQUEUE_FORMAT","%.8i %.8u %.12a %.14j %.3t %16S %.10L %.5D %.4C %.10b %.7m %N (%r) ")
end

-- if SQUEUE_SORT is not already defined, define it
if not os.getenv("SQUEUE_SORT") then
	setenv("SQUEUE_SORT", "-t,e,S")
end

-- if SACCT_FORMAT is not already defined, define it
if not os.getenv("SACCT_FORMAT") then
	setenv("SACCT_FORMAT","Account,User,JobID,Start,End,AllocCPUS,Elapsed,AllocTRES%30,CPUTime,AveRSS,MaxRSS,MaxRSSTask,MaxRSSNode,NodeList,ExitCode,State%20")
end
set_alias("quota", "diskusage_report")
