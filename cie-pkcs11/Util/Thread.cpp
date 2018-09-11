
#include "Thread.h"
#include "util.h"
#include "UtilException.h"

static char *szCompiledFile=__FILE__;

CThread::CThread(void)
{
	hThread=NULL;
	dwThreadID=0;
}

CThread::~CThread(void)
{
	dwThreadID=0;
	if (hThread)
		CloseHandle(hThread);
}

void CThread::close()
{
	dwThreadID = 0;
	if (hThread)
		CloseHandle(hThread);
	hThread = nullptr;
}

void CThread::createThread(void *threadFunc,void *threadData)
{
	init_func
	if (dwThreadID != 0 || hThread!=nullptr)
		throw CStringException("Thread non ancora chiuso");

#ifdef WIN32
	hThread=CreateThread(NULL,0,(LPTHREAD_START_ROUTINE)threadFunc,threadData,0,&dwThreadID);
	if (!hThread) {
		throw CWinException();
	}
#endif
	exit_func
}

RESULT CThread::joinThread(DWORD timeout)
{
	init_func
#ifdef WIN32
	DWORD ret=WaitForSingleObject(hThread,timeout);
	if (ret == 0)
		return OK;
	if (ret==WAIT_FAILED) {
		// verifico se il thread � stato gi� chiuso...
		if (GetLastError()==ERROR_INVALID_HANDLE)
			return OK;
		return FAIL;
	}
	return FAIL;
#endif
	exit_func
}

void CThread::exitThread(DWORD dwCode)
{
	init_func
#ifdef WIN32
	if (hThread) {
		if (!CloseHandle(hThread))
			throw CWinException();
		hThread=NULL;
		ExitThread(dwCode);
		dwThreadID=0;
	}
#endif
	exit_func
}

void CThread::terminateThread()
{
	init_func
#ifdef WIN32
	dwThreadID=0;
#pragma warning(suppress: 6258)
	BOOL ris = TerminateThread(hThread, 0);
	if (!ris)
		throw CWinException();
#endif
	exit_func
}
