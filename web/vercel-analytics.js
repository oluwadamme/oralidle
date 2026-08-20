// Vercel Web Analytics
// This script is loaded from the bundled @vercel/analytics package
// and automatically tracks page views when deployed to Vercel.

(function() {
  // Check if we're in a browser environment
  if (typeof window === 'undefined') return;

  // Initialize the analytics queue
  window.va = window.va || function () { 
    (window.vaq = window.vaq || []).push(arguments); 
  };

  // Load the Vercel Analytics script
  var script = document.createElement('script');
  script.defer = true;
  script.src = '/_vercel/insights/script.js';
  
  // Handle script load errors gracefully
  script.onerror = function() {
    console.warn('Vercel Analytics: Failed to load script. Analytics may not be available.');
  };
  
  var firstScript = document.getElementsByTagName('script')[0];
  if (firstScript && firstScript.parentNode) {
    firstScript.parentNode.insertBefore(script, firstScript);
  } else {
    document.head.appendChild(script);
  }
})();
