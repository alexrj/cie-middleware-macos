
#include "CardLocker.h"

extern CLog Log;

static char *szCompiledFile=__FILE__;

CCardLocker::CCardLocker(SCARDHANDLE card)
{
	hCard=card;
	Lock();
}

CCardLocker::~CCardLocker(void)
{
	Unlock();
}

void CCardLocker::Lock()
{
	init_func

	SCardBeginTransaction(hCard);

	exit_func
}

void CCardLocker::Unlock()
{
	init_func

	SCardEndTransaction(hCard,SCARD_LEAVE_CARD);

	exit_func
}

