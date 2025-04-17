import { memo, PropsWithChildren, useCallback, useEffect, useMemo, useState } from 'react';
import { GitHubContext } from '../githubContext';
import { RepoType } from '../../types/general';
import { getGitHubRepos, syncGitHubRepo as apiSyncGitHubRepo } from '../../services/api';

type Props = {};

const GitHubContextProvider = ({ children }: PropsWithChildren<Props>) => {
  const [githubRepos, setGithubRepos] = useState<RepoType[]>([]);

  const refreshGitHubRepos = useCallback(async () => {
    try {
      const repos = await getGitHubRepos();
      setGithubRepos(repos);
    } catch (error) {
      console.error('Failed to fetch GitHub repos:', error);
    }
  }, []);

  const syncGitHubRepo = useCallback(async (repoRef: string) => {
    try {
      await apiSyncGitHubRepo(repoRef);
      await refreshGitHubRepos();
    } catch (error) {
      console.error('Failed to sync GitHub repo:', error);
    }
  }, [refreshGitHubRepos]);

  useEffect(() => {
    refreshGitHubRepos();
  }, [refreshGitHubRepos]);

  const contextValue = useMemo(() => {
    return {
      githubRepos,
      refreshGitHubRepos,
      syncGitHubRepo,
    };
  }, [githubRepos, refreshGitHubRepos, syncGitHubRepo]);

  return (
    <GitHubContext.Provider value={contextValue}>
      {children}
    </GitHubContext.Provider>
  );
};

export default memo(GitHubContextProvider);
