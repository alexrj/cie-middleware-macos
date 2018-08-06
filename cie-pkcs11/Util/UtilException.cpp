
#include <windows.h>
#include "UtilException.h"
#include <imagehlp.h>
#include <stdio.h>

extern thread_local std::unique_ptr<CFuncCallInfoList> callQueue;

logged_error::logged_error(std::string message) {
    const char* msg = message.c_str();
    logged_error(msg);
}

logged_error::logged_error(const char *message) : std::runtime_error(message) {
	OutputDebugString(what());
	CFuncCallInfoList *ptr = callQueue.get();
	while (ptr != nullptr) {
		OutputDebugString(ptr->info->FunctionName());
		ptr = ptr->next.get();
	}
}

scard_error::scard_error(StatusWord sw) : logged_error(stdPrintf("Errore smart card:%04x", sw)) { }

windows_error::windows_error(long ris) : logged_error(stdPrintf("Errore windows:%s (%08x) ", WinErr(ris), ris)) {}
