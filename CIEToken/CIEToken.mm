//
//  Token.m
//  CIEToken
//
//  Created by ugo chirico on 06/10/18.
//  Copyright © 2018 IPZS. All rights reserved.
//

#import "CIEToken.h"


typedef CK_RV (*C_GETFUNCTIONLIST)(CK_FUNCTION_LIST_PTR_PTR ppFunctionList);
CK_FUNCTION_LIST_PTR g_pFuncList;

// PKCS#11 wrapper functions
bool initPKCS11();
void closePKCS11();
CK_SLOT_ID_PTR getSlotList(bool bPresent, CK_ULONG* pulCount);
CK_SESSION_HANDLE openSession(CK_SLOT_ID slotid);
bool findObject(CK_SESSION_HANDLE hSession, CK_ATTRIBUTE_PTR pAttributes, CK_ULONG ulCount, CK_OBJECT_HANDLE_PTR pObjects, CK_ULONG_PTR pulObjCount);

@implementation NSData(hexString)

- (NSString *)hexString {
    
    NSUInteger capacity = self.length * 2;
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:capacity];
    const unsigned char *dataBuffer = (const unsigned char*) self.bytes;
    
    for (NSInteger i = 0; i < self.length; i++) {
        [stringBuffer appendFormat:@"%02lX", (unsigned long)dataBuffer[i]];
    }
    
    return stringBuffer;
}

@end

@implementation TKTokenKeychainItem(CIEDataFormat)

- (void)setName:(NSString *)name {
    if (self.label != nil) {
        self.label = [NSString stringWithFormat:@"%@ (%@)", name, self.label];
    } else {
        self.label = name;
    }
}

@end

@implementation CIETokenKeychainKey

- (instancetype)initWithCertificate:(SecCertificateRef)certificateRef objectID:(TKTokenObjectID)objectID certificateID:(TKTokenObjectID)certificateID alwaysAuthenticate:(BOOL)alwaysAuthenticate {
    if (self = [super initWithCertificate:certificateRef objectID:objectID]) {
        _certificateID = certificateID;
        _alwaysAuthenticate = alwaysAuthenticate;
    }
    return self;
}

@end

@implementation CIEToken

- (instancetype)initWithSmartCard:(TKSmartCard *)smartCard AID:(NSData *)AID tokenDriver:(CIETokenDriver *)tokenDriver error:(NSError **)error
{
    const char* szCryptoki = "libcie-pkcs11.dylib";
    void* hModule = dlopen(szCryptoki, RTLD_LAZY);
    if(!hModule)
    {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware not found" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:100 userInfo:errorDetail];
        return nil;
    }
    
    C_GETFUNCTIONLIST pfnGetFunctionList=(C_GETFUNCTIONLIST)dlsym(hModule, "C_GetFunctionList");
    if(!pfnGetFunctionList)
    {
        dlclose(hModule);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's functions list not found'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
    
    CK_RV rv = pfnGetFunctionList(&g_pFuncList);
    if(rv != CKR_OK)
    {
        dlclose(hModule);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's functions list fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
    
        
    // TOTO Insert code here to enumerate token objects and populate keychainContents with instances of TKTokenKeychainCertificate, TKTokenKeychainKey, etc.
    
    if(!initPKCS11())
    {
        dlclose(hModule);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's init fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
    CK_ULONG ulCount = 0;
    CK_SLOT_ID_PTR pSlotList = getSlotList(true, &ulCount);
    if(!pSlotList || ulCount == 0)
    {
        dlclose(hModule);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's getSlotList fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
//        if(g_nLogLevel > 1)
//            std::cout << "  -> Chiede le info sul token inserito\n    - C_GetTokenInfo" << std::endl;
        
    CK_TOKEN_INFO tkInfo;
    
    rv = g_pFuncList->C_GetTokenInfo(pSlotList[0], &tkInfo);
    if (rv != CKR_OK)
    {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's getSlotList fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
//        if(g_nLogLevel > 3)
//        {
//            std::cout << "  -> Token Info:" << std::endl;
//            std::cout << "    - Label: " << tkInfo.label << std::endl;
//            std::cout << "    - Model: " << tkInfo.model << std::endl;
//            std::cout << "    - S/N: " << tkInfo.serialNumber<< std::endl;
//        }

        
    NSData *tokenSerial = [NSData dataWithBytes:tkInfo.serialNumber length:16];
    NSString *stringBuffer = [tokenSerial hexString];
    
    NSString* instanceID = [@"CIE-" stringByAppendingString:stringBuffer];
        
    CK_SESSION_HANDLE hSession = openSession(pSlotList[0]);
    if(!hSession)
    {
        dlclose(hModule);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware openSession fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
    CK_OBJECT_HANDLE phObject[1];
    CK_ULONG ulObjCount = 0;
    
    CK_OBJECT_CLASS ckClass = CKO_CERTIFICATE;
    
    CK_ATTRIBUTE template_ck[] = {
        {CKA_CLASS, &ckClass, sizeof(ckClass)}};
    
    if(!findObject(hSession, template_ck, 1, phObject, &ulObjCount) || ulObjCount == 0)
    {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware's findObject fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
    
    // Get Cert Data
    CK_ATTRIBUTE    attr[]      = {
        {CKA_VALUE, NULL, 0},
    };
    
    CK_OBJECT_HANDLE hObject = *phObject;
    
    rv = g_pFuncList->C_GetAttributeValue(hSession, hObject, attr, 1);
    if (rv != CKR_OK)
    {
//            error(rv);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware C_GetAttributeValue fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
    attr[0].pValue = malloc(attr[0].ulValueLen);
    
    rv = g_pFuncList->C_GetAttributeValue(hSession, hObject, attr, 1);
    if (rv != CKR_OK)
    {
//            error(rv);
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Middleware C_GetAttributeValue fails'" forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:@"CIEToken" code:101 userInfo:errorDetail];
        return nil;
    }
        
        
    NSData* certData = [NSData dataWithBytes:attr[0].pValue length:attr[0].ulValueLen];

    if (self = [super initWithSmartCard:smartCard AID:AID instanceID:instanceID tokenDriver:tokenDriver]) {
        
        NSMutableArray<TKTokenKeychainItem *> *items = [NSMutableArray array];
        
        NSString *certificateName = @"CIE0";
        NSString *keyName = @"CIE0_KEY";
        
        if (![self populateIdentityFromSmartCard:smartCard into:items certificateData:certData certificateName:certificateName keyName:keyName sign:YES keyManagement:YES alwaysAuthenticate:NO error:error])
        {
            return nil;
        }
        
        [self.keychainContents fillWithItems:items];
    }
    
    return self;
}

- (TKTokenSession *)token:(TKToken *)token createSessionWithError:(NSError **)error {
    return [[CIETokenSession alloc] initWithToken:self];
}

- (BOOL)populateIdentityFromSmartCard:(TKSmartCard *)smartCard into:(NSMutableArray<TKTokenKeychainItem *> *)items certificateData:(NSData*)certificateData certificateName:(NSString *)certificateName keyName:(NSString *)keyName sign:(BOOL)sign keyManagement:(BOOL)keyManagement alwaysAuthenticate:(BOOL)alwaysAuthenticate error:(NSError **)error
{
    // Create certificate item.
    id certificate = CFBridgingRelease(SecCertificateCreateWithData(kCFAllocatorDefault, (CFDataRef)certificateData));
    if (certificate == NULL) {
        if (error != nil) {
            *error = [NSError errorWithDomain:TKErrorDomain code:TKErrorCodeCorruptedData userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"CORRUPTED_CERT", nil)}];
        }
        return NO;
    }
    
    TKTokenObjectID certificateID = certificateName;
    
    TKTokenKeychainCertificate *certificateItem = [[TKTokenKeychainCertificate alloc] initWithCertificate:(__bridge SecCertificateRef)certificate objectID:certificateID];
    if (certificateItem == nil) {
        return NO;
    }
    [certificateItem setName:certificateName];
    
    // Create key item.
    TKTokenKeychainKey *keyItem = [[CIETokenKeychainKey alloc] initWithCertificate:(__bridge SecCertificateRef)certificate objectID:keyName certificateID:certificateItem.objectID alwaysAuthenticate:alwaysAuthenticate];
    if (keyItem == nil) {
        return NO;
    }
    [keyItem setName:keyName];
    
    NSMutableDictionary<NSNumber *, TKTokenOperationConstraint> *constraints = [NSMutableDictionary dictionary];
    keyItem.canSign = sign;
    keyItem.suitableForLogin = sign;
    TKTokenOperationConstraint constraint = alwaysAuthenticate ? CIEConstraintPINAlways : CIEConstraintPIN;
    if (sign) {
        constraints[@(TKTokenOperationSignData)] = constraint;
    }
    if ([keyItem.keyType isEqual:(id)kSecAttrKeyTypeRSA]) {
        keyItem.canDecrypt = keyManagement;
        if (keyManagement) {
            constraints[@(TKTokenOperationDecryptData)] = constraint;
        }
    } else if ([keyItem.keyType isEqual:(id)kSecAttrKeyTypeECSECPrimeRandom]) {
        keyItem.canPerformKeyExchange = keyManagement;
        if (keyManagement) {
            constraints[@(TKTokenOperationPerformKeyExchange)] = constraint;
        }
    }
    keyItem.constraints = constraints;
    [items addObject:certificateItem];
    [items addObject:keyItem];
    
    return YES;
}

bool initPKCS11()
{
    // Inizializza
//    if(g_nLogLevel > 1)
//        std::cout << "  -> Inizializza la libreria\n    - C_Initialize" << std::endl;
    
    CK_C_INITIALIZE_ARGS* pInitArgs = NULL_PTR;
    CK_RV rv = g_pFuncList->C_Initialize(pInitArgs);
    if(rv != CKR_OK)
    {
//        error(rv);
        return false;
    }
    
//    if(g_nLogLevel > 1)
//        std::cout << "  -- Inizializzazione completata " << std::endl;
    
    return true;
}

void closePKCS11()
{
//    if(g_nLogLevel > 1)
//        std::cout << "  -> Chiude la sessione con la libreria\n    - C_Finalize" << std::endl;
//
    CK_RV rv = g_pFuncList->C_Finalize(NULL_PTR);
    if(rv != CKR_OK)
    {
//        error(rv);
        return;
    }
}

CK_SLOT_ID_PTR getSlotList(bool bPresent, CK_ULONG* pulCount)
{
    // carica gli slot disponibili
    
//    if(g_nLogLevel > 1)
//        std::cout << "  -> Chiede la lista degli slot disponibili\n    - C_GetSlotList\n    - C_GetSlotInfo" << std::endl;
//
    CK_SLOT_ID_PTR pSlotList;
    
    // riceve la lista degli slot disponibili
    CK_RV rv = g_pFuncList->C_GetSlotList(bPresent, NULL_PTR, pulCount);
    if (rv != CKR_OK)
    {
//        error(rv);
        return NULL_PTR;
    }
    
    if (*pulCount > 0)
    {
//        if(g_nLogLevel > 2)
//            std::cout << "  -> Slot disponibili: " << *pulCount << std::endl;
//
        pSlotList = (CK_SLOT_ID_PTR) malloc(*pulCount * sizeof(CK_SLOT_ID));
        rv = g_pFuncList->C_GetSlotList(bPresent, pSlotList, pulCount);
        if (rv != CKR_OK)
        {
//            error(rv);
            free(pSlotList);
            return NULL_PTR;
        }
        
        return pSlotList;
    }
    else
    {
//        std::cout << "  -> Nessuno Slot disponibile " << std::endl;
        return NULL_PTR;
    }
    
//    if(g_nLogLevel > 1)
//        std::cout << "  -- Richiesta completata " << std::endl;
}

CK_SESSION_HANDLE openSession(CK_SLOT_ID slotid)
{
//    if(g_nLogLevel > 1)
//        std::cout << "  -> Apre una sessione con lo slot " << slotid << " - C_OpenSession" << std::endl;
//
    
    CK_SESSION_HANDLE hSession;
    CK_RV rv = g_pFuncList->C_OpenSession(slotid, CKF_RW_SESSION | CKF_SERIAL_SESSION, NULL, NULL, &hSession);
    if (rv != CKR_OK)
    {
//        error(rv);
        return NULL_PTR;
    }
    
//    if(g_nLogLevel > 1)
//        std::cout << "  -- Sessione aperta: " << hSession << std::endl;
//
    return hSession;
}

bool findObject(CK_SESSION_HANDLE hSession, CK_ATTRIBUTE_PTR pAttributes, CK_ULONG ulCount, CK_OBJECT_HANDLE_PTR pObjects, CK_ULONG_PTR pulObjCount)
{
//    if(g_nLogLevel > 1)
//        std::cout << "  -> Ricerca di oggetti \n    - C_FindObjectsInit\n    - C_FindObjects\n    - C_FindObjectsFinal" << std::endl;
//
    CK_RV rv;
    
    rv = g_pFuncList->C_FindObjectsInit(hSession, pAttributes, ulCount);
    if (rv != CKR_OK)
    {
//        std::cout << "  ->     - C_FindObjectsInit fails" << std::endl;
//        error(rv);
        return false;
    }
    
//    if(g_nLogLevel > 2)
//        std::cout << "      - C_FindObjectsInit OK" << std::endl;
    
    rv = g_pFuncList->C_FindObjects(hSession, pObjects, *pulObjCount, pulObjCount);
    if (rv != CKR_OK)
    {
//        std::cout << "      - C_FindObjects fails found" << *pulObjCount << std::endl;
//        error(rv);
        g_pFuncList->C_FindObjectsFinal(hSession);
        return false;
    }
    
//    if(g_nLogLevel > 2)
//        std::cout << "      - C_FindObjects OK. Objects found: " << *pulObjCount << std::endl;
    
    rv = g_pFuncList->C_FindObjectsFinal(hSession);
    if (rv != CKR_OK)
    {
//        std::cout << "      - C_FindObjectsFinal fails" << std::endl;
//        error(rv);
        g_pFuncList->C_FindObjectsFinal(hSession);
        return false;
    }
    
//    if(g_nLogLevel > 1)
//        std::cout << "      - C_FindObjectsFinal OK" << std::endl;
    
    return true;
}

@end
