#pragma once

#pragma pack(1)
#include "pkcs11.h"
#pragma pack()

#ifdef WIN32
#include <winscard.h>
#else
#include <PCSC/winscard.h>
#endif

#define MAXVAL 0xffffff
#define MAXSESSIONS MAXVAL

#ifdef WIN32
#define CK_ENTRY __declspec(dllexport)
#else
#define CK_ENTRY 
#endif
#define LIBRARY_VERSION_MAJOR 2
#define LIBRARY_VERSION_MINOR 0

#define PIN_LEN 8
#define USER_PIN_ID 0x10

#ifdef WIN32

#define init_p11_func \
	CFuncCallInfo info(__FUNCTION__, Log); \
	try {

#define exit_p11_func } \
	catch (p11_error &p11Err) { \
		OutputDebugString("EXCLOG->"); \
		OutputDebugString(p11Err.what()); \
		OutputDebugString("<-EXCLOG");\
		return p11Err.getP11ErrorCode(); \
	} \
	catch (std::exception &err) { \
		OutputDebugString("EXCLOG->"); \
		OutputDebugString(err.what()); \
		OutputDebugString("<-EXCLOG");\
		return CKR_GENERAL_ERROR; \
	} \
catch (...) { return CKR_GENERAL_ERROR; }
        
#else
        
#define init_p11_func \
try {
        
#define exit_p11_func } \
catch (p11_error &p11Err) { \
OutputDebugString("EXCLOG->"); \
OutputDebugString(p11Err.what()); \
OutputDebugString("<-EXCLOG");\
return p11Err.getP11ErrorCode(); \
} \
catch (std::exception &err) { \
OutputDebugString("EXCLOG->"); \
OutputDebugString(err.what()); \
OutputDebugString("<-EXCLOG");\
return CKR_GENERAL_ERROR; \
} \
catch (...) { return CKR_GENERAL_ERROR; }

#endif
        
extern "C" {
	CK_RV CK_ENTRY C_UpdateSlotList();
}
