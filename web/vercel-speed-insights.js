// Vercel Speed Insights
// This script is loaded from the bundled @vercel/speed-insights package
// and automatically tracks performance metrics when deployed to Vercel.

(function() {
  // Check if we're in a browser environment
  if (typeof window === 'undefined') return;

  // Initialize the speed insights queue
  window.si = window.si || function () { 
    (window.siq = window.siq || []).push(arguments); 
  };

  // Load the Vercel Speed Insights script
  var script = document.createElement('script');
  script.defer = true;
  script.src = '/_vercel/speed-insights/script.js';
  
  // Handle script load errors gracefully
  script.onerror = function() {
    console.warn('Vercel Speed Insights: Failed to load script. Speed metrics may not be available.');
  };
  
  var firstScript = document.getElementsByTagName('script')[0];
  if (firstScript && firstScript.parentNode) {
    firstScript.parentNode.insertBefore(script, firstScript);
  } else {
    document.head.appendChild(script);
  }
})();
