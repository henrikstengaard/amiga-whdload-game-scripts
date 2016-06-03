# registry setting that will change the .NET framework loaded systemwide, which will in turn allow PowerShell to use .NET 4.0 classes
reg add hklm\software\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1
reg add hklm\software\wow6432node\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1