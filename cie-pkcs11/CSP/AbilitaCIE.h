//
//  AbilitaCIE.h
//  cie-pkcs11
//
//  Created by ugo chirico on 02/09/18.
//  Copyright © 2018 IPZS. All rights reserved.
//
#include "../PKCS11/cryptoki.h"

#define SCARD_ATTR_VALUE(Class, Tag) ((((uint32_t)(Class)) << 16) | ((uint32_t)(Tag)))
#define SCARD_CLASS_ICC_STATE       9   /**< ICC State specific definitions */
#define SCARD_ATTR_ATR_STRING SCARD_ATTR_VALUE(SCARD_CLASS_ICC_STATE, 0x0303) /**< Answer to reset (ATR) string. */

/* CK_NOTIFY is an application callback that processes events */
typedef CK_CALLBACK_FUNCTION(CK_RV, PROGRESS_CALLBACK)(
                                               const int progress,
                                               const char* szMessage);

typedef CK_RV (*AbilitaCIEfn)(const char*  szPAN,
                              const char*  szPIN,
                              int* attempts,
                              PROGRESS_CALLBACK progressCallBack);


//typedef CK_RV abilitaCIE(const char*  szPAN, const char*  szPIN, PROGRESS_CALLBACK progressCallBack)

