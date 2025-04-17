import { useCallback, useContext, useState } from 'react';
import { GitHubContext } from '../../context/githubContext';
import { Button } from '../Button';
import { TextInput } from '../TextInput';

const GitHubLogin = () => {
  const { login } = useContext(GitHubContext);
  const [token, setToken] = useState('');

  const handleLogin = useCallback(async () => {
    if (token) {
      await login(token);
    }
  }, [token, login]);

  return (
    <div className="flex flex-col gap-4 p-4">
      <TextInput
        value={token}
        onChange={(e) => setToken(e.target.value)}
        placeholder="Enter GitHub token"
        type="password"
      />
      <Button onClick={handleLogin} disabled={!token}>
        Connect GitHub
      </Button>
    </div>
  );
};

export default GitHubLogin;
