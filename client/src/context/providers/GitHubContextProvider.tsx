import { PropsWithChildren, useCallback, useMemo, useState } from 'react';
import { GitHubContext, GitHubUser } from '../githubContext';
import { getGitHubUser, setGitHubToken } from '../../services/api';

const GitHubContextProvider = ({ children }: PropsWithChildren) => {
  const [user, setUser] = useState<GitHubUser | null>(null);
  const [token, setToken] = useState<string | null>(null);

  const login = useCallback(async (newToken: string) => {
    try {
      setGitHubToken(newToken);
      const userData = await getGitHubUser();
      setUser(userData);
      setToken(newToken);
    } catch (error) {
      console.error('Failed to login with GitHub token:', error);
      setUser(null);
      setToken(null);
    }
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    setToken(null);
  }, []);

  const contextValue = useMemo(
    () => ({
      isAuthenticated: !!token,
      user,
      token,
      login,
      logout,
    }),
    [user, token, login, logout],
  );

  return (
    <GitHubContext.Provider value={contextValue}>
      {children}
    </GitHubContext.Provider>
  );
};

export default GitHubContextProvider;
