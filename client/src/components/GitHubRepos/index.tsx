import { useCallback, useContext, useEffect, useState } from 'react';
import { GitHubContext } from '../../context/githubContext';
import { getGitHubRepos } from '../../services/api';
import { Button } from '../Button';
import { RepositoryIcon } from '../../icons';

interface GitHubRepo {
  id: number;
  name: string;
  full_name: string;
  description: string;
  private: boolean;
}

const GitHubRepos = () => {
  const { isAuthenticated } = useContext(GitHubContext);
  const [repos, setRepos] = useState<GitHubRepo[]>([]);
  const [loading, setLoading] = useState(false);

  const loadRepos = useCallback(async () => {
    if (!isAuthenticated) return;
    
    try {
      setLoading(true);
      const repoData = await getGitHubRepos();
      setRepos(repoData);
    } catch (error) {
      console.error('Failed to load GitHub repos:', error);
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    loadRepos();
  }, [loadRepos]);

  if (!isAuthenticated) {
    return null;
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold">GitHub Repositories</h2>
        <Button onClick={loadRepos} disabled={loading}>
          {loading ? 'Loading...' : 'Refresh'}
        </Button>
      </div>
      <div className="grid gap-4">
        {repos.map((repo) => (
          <div
            key={repo.id}
            className="flex items-center gap-3 p-3 border rounded-lg"
          >
            <RepositoryIcon sizeClassName="w-5 h-5" />
            <div>
              <div className="font-medium">{repo.name}</div>
              {repo.description && (
                <div className="text-sm text-gray-500">{repo.description}</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default GitHubRepos;
