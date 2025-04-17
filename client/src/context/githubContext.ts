import { createContext } from 'react';
import { RepoType } from '../types/general';

type ContextType = {
  githubRepos: RepoType[];
  refreshGitHubRepos: () => Promise<void>;
  syncGitHubRepo: (repoRef: string) => Promise<void>;
};

export const GitHubContext = createContext<ContextType>({
  githubRepos: [],
  refreshGitHubRepos: async () => {},
  syncGitHubRepo: async () => {},
});
