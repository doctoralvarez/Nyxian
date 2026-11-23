/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-22): App Store signing (m_bAppStore and m_mapAssets).
*/
#pragma once
#include "common.h"
#include "json.h"
#include "openssl.h"
#include <vector>
#include <map>

class ZBundle
{
public:
	ZBundle();
    bool ConfigureFolderSign(ZSignAsset *pSignAsset, const string &strFolder, const string &strBundleID, const string &strBundleVersion, const string &strDisplayName, const string &strDyLibFile, bool bForce, bool bWeakInject, bool bEnableCache, bool dontGenerateEmbeddedMobileProvision);
    bool StartSign(bool enableCache);
    int GetSignCount();

public:
	bool SignFolder(ZSignAsset* pSignAsset,
					const string& strFolder,
					const string& strBundleId,
					const string& strBundleVersion,
					const string& strDisplayName,
					const vector<string>& arrDylibFiles,
					bool bForce,
					bool bWeakInject,
					bool bEnableCache);

private:
	bool SignNode(jvalue& jvNode);
	void GetNodeChangedFiles(jvalue& jvNode);
	void GetChangedFiles(jvalue& jvNode, vector<string>& arrChangedFiles);
	bool ModifyPluginsBundleId(const string& strOldBundleId, const string& strNewBundleId);
	bool ModifyBundleInfo(const string& strBundleId, const string& strBundleVersion, const string& strDisplayName);

private:
	bool FindAppFolder(const string& strFolder, string& strAppFolder);
	bool GetObjectsToSign(const string& strFolder, jvalue& jvInfo);
	bool GetSignFolderInfo(const string& strFolder, jvalue& jvNode, bool bGetName = false);
    int GetSignCount(jvalue &jvNode);


private:
	bool GenerateCodeResources(const string& strFolder, jvalue& jvCodeRes);

private:
	bool			m_bForceSign;
	bool			m_bWeakInject;
	ZSignAsset*		m_pSignAsset;
	vector<string>	m_arrInjectDylibs;
    jvalue config;

public:
	/* fork doctoralvarez/Nyxian: App Store signing — each bundle (the app and
	   every .appex) with its own profile, its embedded.mobileprovision and a
	   _CodeSignature/CodeResources (LiveContainer leaves those out) */
	bool			m_bAppStore;
	std::map<string, ZSignAsset*> m_mapAssets;

public:
	string			m_strAppFolder;
    std::function<void()> progressHandler;
    string signFailedFiles;
};
