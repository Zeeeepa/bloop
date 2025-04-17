import React, { memo, useCallback, useContext, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { UIContext } from '../context/uiContext';
import Header from '../components/Header';
import useKeyboardNavigation from '../hooks/useKeyboardNavigation';
import { SettingSections } from '../types/general';
import SectionsNav from '../components/SectionsNav';
import { CogIcon, GitHubIcon } from '../icons';
import General from './General';
import Preferences from './Preferences';
import GitHubLogin from '../components/GitHubLogin';
import GitHubRepos from '../components/GitHubRepos';
import { GitHubContext } from '../context/githubContext';

type Props = {};

const Settings = ({}: Props) => {
  const { t } = useTranslation();
  const {
    isSettingsOpen,
    setSettingsOpen,
    settingsSection,
    setSettingsSection,
  } = useContext(UIContext.Settings);
  const { isAuthenticated } = useContext(GitHubContext);

  const handleKeyEvent = useCallback((e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      setSettingsOpen(false);
    }
  }, []);
  useKeyboardNavigation(handleKeyEvent, !isSettingsOpen);

  const settingsSections = useMemo(() => {
    return [
      {
        title: t('Account settings'),
        Icon: CogIcon,
        items: [
          {
            type: SettingSections.GENERAL,
            label: t('General'),
            onClick: setSettingsSection,
          },
          {
            type: SettingSections.PREFERENCES,
            label: t('Preferences'),
            onClick: setSettingsSection,
          },
        ],
      },
      {
        title: t('Integrations'),
        Icon: GitHubIcon,
        items: [
          {
            type: SettingSections.GITHUB,
            label: t('GitHub'),
            onClick: setSettingsSection,
          },
        ],
      },
    ];
  }, [t]);

  const renderContent = () => {
    switch (settingsSection) {
      case SettingSections.GENERAL:
        return <General />;
      case SettingSections.PREFERENCES:
        return <Preferences />;
      case SettingSections.GITHUB:
        return (
          <div className="flex-1">
            <h2 className="text-2xl font-bold mb-6">{t('GitHub Integration')}</h2>
            {!isAuthenticated ? (
              <GitHubLogin />
            ) : (
              <GitHubRepos />
            )}
          </div>
        );
      default:
        return null;
    }
  };

  return isSettingsOpen ? (
    <div className="fixed top-0 bottom-0 left-0 right-0 bg-bg-sub select-none z-40">
      <Header type="settings" />
      <div className="mx-auto my-8 px-3 flex max-w-6xl items-start justify-start w-full gap-13">
        <SectionsNav<SettingSections>
          sections={settingsSections}
          activeItem={settingsSection}
        />
        {renderContent()}
        <div className="w-56 flex-1 hidden lg:block" />
      </div>
    </div>
  ) : null;
};

export default memo(Settings);
