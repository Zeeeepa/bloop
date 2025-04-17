import { createContext } from 'react';

export interface GitHubUser {
  login: string;
  id: number;
  avatar_url: string;
  name: string;
}

export interface GitHubContextType {
  isAuthenticated: boolean;
  user: GitHubUser | null;
  token: string | null;
  login: (token: string) => Promise<void>;
  logout: () => void;
}

export const GitHubContext = createContext<GitHubContextType>({
  isAuthenticated: false,
  user: null,
  token: null,
  login: async () => {},
  logout: () => {},
});
