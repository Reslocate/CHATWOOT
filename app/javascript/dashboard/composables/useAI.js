import { computed, onMounted } from 'vue';
import {
  useStore,
  useStoreGetters,
  useMapGetter,
} from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { DEEPSEEK_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import DeepseekAPI from 'dashboard/api/integrations/deepseek';

/**
 * Cleans and normalizes a list of labels.
 * @param {string} labels - A comma-separated string of labels.
 * @returns {string[]} An array of cleaned and unique labels.
 */
const cleanLabels = labels => {
  return labels
    .toLowerCase() // Set it to lowercase
    .split(',') // split the string into an array
    .filter(label => label.trim()) // remove any empty strings
    .map(label => label.trim()) // trim the words
    .filter((label, index, self) => self.indexOf(label) === index);
};

/**
 * A composable function for AI-related operations in the dashboard.
 * @returns {Object} An object containing AI-related methods and computed properties.
 */
export function useAI() {
  const store = useStore();
  const getters = useStoreGetters();
  const { t } = useI18n();

  /**
   * Computed property for UI flags.
   * @type {import('vue').ComputedRef<Object>}
   */
  const uiFlags = computed(() => getters['integrations/getUIFlags'].value);

  const appIntegrations = useMapGetter('integrations/getAppIntegrations');
  const currentChat = useMapGetter('getSelectedChat');
  const replyMode = useMapGetter('draftMessages/getReplyEditorMode');

  /**
   * Computed property for the AI integration.
   * @type {import('vue').ComputedRef<Object|undefined>}
   */
  const aiIntegration = computed(
    () =>
      appIntegrations.value.find(
        integration =>
          ['deepseek', 'openai'].includes(integration.app_id || integration.id)
      )
  );

  /**
   * Computed property to check if AI integration is enabled.
   * @type {import('vue').ComputedRef<boolean>}
   */
  const isAIIntegrationEnabled = computed(() => !!aiIntegration.value);

  /**
   * Computed property to check if label suggestion feature is enabled.
   * @type {import('vue').ComputedRef<boolean>}
   */
  const isLabelSuggestionFeatureEnabled = computed(() => {
    if (aiIntegration.value) {
      const { settings = {} } = aiIntegration.value || {};
      return settings.label_suggestion;
    }
    return false;
  });

  /**
   * Computed property to check if app integrations are being fetched.
   * @type {import('vue').ComputedRef<boolean>}
   */
  const isFetchingAppIntegrations = computed(() => uiFlags.value.isFetching);

  /**
   * Computed property for the hook ID.
   * @type {import('vue').ComputedRef<string|undefined>}
   */
  const hookId = computed(() => aiIntegration.value?.id);

  /**
   * Computed property for the conversation ID.
   * @type {import('vue').ComputedRef<string|undefined>}
   */
  const conversationId = computed(() => currentChat.value?.id);

  /**
   * Computed property for the draft key.
   * @type {import('vue').ComputedRef<string>}
   */
  const draftKey = computed(
    () => `draft-${conversationId.value}-${replyMode.value}`
  );

  /**
   * Computed property for the draft message.
   * @type {import('vue').ComputedRef<string>}
   */
  const draftMessage = computed(() =>
    getters['draftMessages/get'].value(draftKey.value)
  );

  /**
   * Fetches integrations if they haven't been loaded yet.
   * @returns {Promise<void>}
   */
  const fetchIntegrationsIfRequired = async () => {
    if (!appIntegrations.value.length) {
      await store.dispatch('integrations/get');
    }
  };

  /**
   * Records analytics for AI-related events.
   * @param {string} type - The type of event.
   * @param {Object} payload - Additional data for the event.
   * @returns {Promise<void>}
   */
  const recordAnalytics = async (type, payload) => {
    const event = DEEPSEEK_EVENTS[type.toUpperCase()];
    if (event) {
      useTrack(event, {
        type,
        ...payload,
      });
    }
  };

  /**
   * Fetches label suggestions for the current conversation.
   * @returns {Promise<string[]>} An array of suggested labels.
   */
  const fetchLabelSuggestions = async () => {
    if (!conversationId.value) return [];

    try {
      const api = DeepseekAPI;
      const result = await api.processEvent({
        type: 'label_suggestion',
        hookId: hookId.value,
        conversationId: conversationId.value,
      });

      if (!result || !result.success) {
        console.error('Failed to fetch label suggestions:', result?.error);
        return [];
      }

      // Handle different response formats
      const labels = result.data?.message || result.message || result.data;
      if (!labels) {
        console.error('Invalid label suggestions format:', result);
        return [];
      }

      return cleanLabels(labels);
    } catch (error) {
      console.error('Label suggestion error:', error);
      return [];
    }
  };

  /**
   * Processes an AI event, such as rephrasing content.
   * @param {string} [type='rephrase'] - The type of AI event to process.
   * @returns {Promise<string>} The generated message or an empty string if an error occurs.
   */
  const processEvent = async (type = 'rephrase') => {
    try {
      const api = DeepseekAPI;
      const result = await api.processEvent({
        hookId: hookId.value,
        type,
        content: draftMessage.value,
        conversationId: conversationId.value,
      });

      if (!result || !result.success) {
        const errorMessage = result?.error || result?.message || t('INTEGRATION_SETTINGS.DEEPSEEK.GENERATE_ERROR');
        useAlert(errorMessage);
        return '';
      }

      // Handle different response formats
      const generatedMessage = result.data?.message || result.message || result.data;
      if (!generatedMessage) {
        console.error('Invalid AI response format:', result);
        useAlert(t('INTEGRATION_SETTINGS.DEEPSEEK.GENERATE_ERROR'));
        return '';
      }

      return generatedMessage;
    } catch (error) {
      console.error('AI process event error:', error);
      const errorMessage =
        error?.error ||
        error?.message ||
        error?.response?.data?.error ||
        error?.response?.data?.message ||
        t('INTEGRATION_SETTINGS.DEEPSEEK.GENERATE_ERROR');
      useAlert(errorMessage);
      return '';
    }
  };

  onMounted(() => {
    fetchIntegrationsIfRequired();
  });

  return {
    draftMessage,
    uiFlags,
    appIntegrations,
    currentChat,
    replyMode,
    isAIIntegrationEnabled,
    isLabelSuggestionFeatureEnabled,
    isFetchingAppIntegrations,
    fetchIntegrationsIfRequired,
    recordAnalytics,
    fetchLabelSuggestions,
    processEvent,
  };
}
